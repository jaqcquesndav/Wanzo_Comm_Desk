import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/colors.dart';
import '../../services/sync_service.dart';
import 'package:get_it/get_it.dart';

/// Item de navigation pour le sidebar desktop
class DesktopNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String route;
  final List<DesktopNavItem>? children;
  final bool isDividerBefore;
  final bool isAdhaPanel; // Si cet item ouvre le panneau Adha

  const DesktopNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.route,
    this.children,
    this.isDividerBefore = false,
    this.isAdhaPanel = false,
  });
}

/// Sidebar élégant pour desktop avec fond bleu primaire
class DesktopSidebar extends StatefulWidget {
  /// Index de navigation actuel
  final int currentIndex;

  /// Liste des items de navigation
  final List<DesktopNavItem> items;

  /// Callback quand un item est sélectionné
  final Function(int index)? onItemSelected;

  /// Si le sidebar est étendu ou réduit
  final bool isExpanded;

  /// Callback pour toggler l'expansion
  final VoidCallback? onToggleExpand;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.items,
    this.onItemSelected,
    this.isExpanded = true,
    this.onToggleExpand,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _widthAnimation = Tween<double>(begin: 72, end: 260).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(DesktopSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Couleurs adaptatives pour light/dark mode
    final backgroundColor =
        isDark ? WanzoColors.backgroundSecondaryDark : WanzoColors.primary;
    final textColor = isDark ? WanzoColors.textPrimaryDark : Colors.white;
    final activeItemBg =
        isDark
            ? WanzoColors.primary.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.2);
    final hoverColor =
        isDark
            ? WanzoColors.primary.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.1);

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final isExpanded = _widthAnimation.value > 150;

        return Container(
          width: _widthAnimation.value,
          decoration: BoxDecoration(
            color: backgroundColor,
            // Pas de shadow - le header est au-dessus
          ),
          child: Column(
            children: [
              // Navigation items (plus de header - il est dans le header principal)
              Expanded(
                child: _buildNavItems(
                  context,
                  isExpanded,
                  textColor,
                  activeItemBg,
                  hoverColor,
                  isDark,
                ),
              ),

              // Footer
              _buildFooter(context, isExpanded, textColor, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItems(
    BuildContext context,
    bool isExpanded,
    Color textColor,
    Color activeItemBg,
    Color hoverColor,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isSelected = index == widget.currentIndex;

        // Divider avant l'item si demandé
        if (item.isDividerBefore) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  color: textColor.withValues(alpha: 0.2),
                  thickness: 1,
                  indent: isExpanded ? 16 : 8,
                  endIndent: isExpanded ? 16 : 8,
                ),
              ),
              _buildNavItem(
                context,
                item,
                index,
                isSelected,
                isExpanded,
                textColor,
                activeItemBg,
                hoverColor,
                isDark,
              ),
            ],
          );
        }

        return _buildNavItem(
          context,
          item,
          index,
          isSelected,
          isExpanded,
          textColor,
          activeItemBg,
          hoverColor,
          isDark,
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    DesktopNavItem item,
    int index,
    bool isSelected,
    bool isExpanded,
    Color textColor,
    Color activeItemBg,
    Color hoverColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            if (widget.onItemSelected != null) {
              widget.onItemSelected!(index);
            } else {
              context.go(item.route);
            }
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: hoverColor,
          splashColor: activeItemBg,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 16 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? activeItemBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border:
                  isSelected
                      ? Border.all(
                        color:
                            isDark
                                ? WanzoColors.primary
                                : Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      )
                      : null,
            ),
            child: Row(
              mainAxisAlignment:
                  isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
              children: [
                // Icône
                Icon(
                  isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                  color:
                      isSelected
                          ? (isDark ? WanzoColors.primary : Colors.white)
                          : textColor.withValues(alpha: 0.7),
                  size: 22,
                ),

                // Label (uniquement si étendu)
                if (isExpanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color:
                            isSelected
                                ? (isDark ? WanzoColors.primary : Colors.white)
                                : textColor.withValues(alpha: 0.85),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // Indicateur de sélection
                if (isExpanded && isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? WanzoColors.primary : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    bool isExpanded,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(isExpanded ? 16 : 8),
      child: Column(
        children: [
          Divider(color: textColor.withValues(alpha: 0.2), thickness: 1),
          const SizedBox(height: 8),

          // Bouton de synchronisation manuelle
          _buildSyncButton(context, isExpanded, textColor, isDark),

          const SizedBox(height: 12),
          if (isExpanded)
            Text(
              'Wanzo Desktop v1.0.0',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            )
          else
            Tooltip(
              message: 'Wanzo Desktop v1.0.0',
              child: Icon(
                Icons.info_outline,
                color: textColor.withValues(alpha: 0.5),
                size: 16,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Bouton de synchronisation manuelle avec barre de progression discrète
  Widget _buildSyncButton(
    BuildContext context,
    bool isExpanded,
    Color textColor,
    bool isDark,
  ) {
    return _SyncButtonWidget(
      isExpanded: isExpanded,
      textColor: textColor,
      isDark: isDark,
    );
  }
}

/// Widget autonome pour le bouton de synchronisation
/// Utilise SyncService directement au lieu de SyncStatusBloc
class _SyncButtonWidget extends StatefulWidget {
  final bool isExpanded;
  final Color textColor;
  final bool isDark;

  const _SyncButtonWidget({
    required this.isExpanded,
    required this.textColor,
    required this.isDark,
  });

  @override
  State<_SyncButtonWidget> createState() => _SyncButtonWidgetState();
}

class _SyncButtonWidgetState extends State<_SyncButtonWidget> {
  bool _isSyncing = false;
  bool _hasError = false;
  SyncService? _syncService;
  StreamSubscription<SyncStatus>? _syncStatusSubscription;

  @override
  void initState() {
    super.initState();
    _initSyncService();
  }

  void _initSyncService() {
    try {
      _syncService = GetIt.instance<SyncService>();
      // Écouter les changements de statut de synchronisation
      _syncStatusSubscription = _syncService!.syncStatus.listen((status) {
        if (mounted) {
          setState(() {
            _isSyncing = status == SyncStatus.syncing;
            _hasError = status == SyncStatus.failed;
          });
        }
      });
    } catch (e) {
      debugPrint('SyncService non disponible via GetIt: $e');
    }
  }

  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _triggerManualSync() async {
    if (_isSyncing || _syncService == null) return;

    setState(() {
      _isSyncing = true;
      _hasError = false;
    });

    try {
      final success = await _syncService!.syncData();
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hasError = !success;
        });

        // Afficher un message de succès
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Synchronisation terminée avec succès'),
              backgroundColor: WanzoColors.success,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de synchronisation: $e'),
            backgroundColor: WanzoColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = widget.isExpanded;
    final textColor = widget.textColor;
    final isDark = widget.isDark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton de sync
        Tooltip(
          message:
              _isSyncing
                  ? 'Synchronisation en cours...'
                  : _hasError
                  ? 'Erreur de synchronisation. Réessayer'
                  : 'Synchroniser les données',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSyncing ? null : _triggerManualSync,
              borderRadius: BorderRadius.circular(12),
              hoverColor: textColor.withValues(alpha: 0.1),
              splashColor: WanzoColors.primary.withValues(alpha: 0.2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isExpanded ? 12 : 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      _isSyncing
                          ? WanzoColors.primary.withValues(alpha: 0.15)
                          : _hasError
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _isSyncing
                            ? WanzoColors.primary.withValues(alpha: 0.4)
                            : _hasError
                            ? Colors.red.withValues(alpha: 0.4)
                            : textColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      isExpanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icône animée pendant la sync
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child:
                          _isSyncing
                              ? SizedBox(
                                key: const ValueKey('syncing'),
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark ? WanzoColors.primary : Colors.white,
                                  ),
                                ),
                              )
                              : Icon(
                                key: const ValueKey('sync_icon'),
                                _hasError ? Icons.sync_problem : Icons.sync,
                                color:
                                    _hasError
                                        ? Colors.red.withValues(alpha: 0.8)
                                        : textColor.withValues(alpha: 0.7),
                                size: 18,
                              ),
                    ),

                    if (isExpanded) ...[
                      const SizedBox(width: 10),
                      Text(
                        _isSyncing ? 'Sync...' : 'Sync',
                        style: TextStyle(
                          color:
                              _hasError
                                  ? Colors.red.withValues(alpha: 0.8)
                                  : textColor.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Barre de progression discrète en dessous du bouton
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isSyncing ? 3 : 0,
          margin: const EdgeInsets.only(top: 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child:
                _isSyncing
                    ? LinearProgressIndicator(
                      backgroundColor: textColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark
                            ? WanzoColors.primary
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
