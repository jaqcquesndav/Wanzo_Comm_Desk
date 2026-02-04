import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../constants/colors.dart';
import '../../../features/adha/bloc/adha_bloc.dart';
import '../../../features/adha/bloc/adha_state.dart';

/// État global du layout desktop partagé entre les composants
class DesktopLayoutState extends ChangeNotifier {
  bool _isSidebarExpanded = true;
  bool _isAdhaPanelOpen = false;
  bool _isAdhaPanelFullscreen = false;
  double _adhaPanelWidth = 400.0;

  static const double minAdhaPanelWidth = 320.0;
  static const double maxAdhaPanelWidth = 800.0;
  static const double defaultAdhaPanelWidth = 400.0;

  bool get isSidebarExpanded => _isSidebarExpanded;
  bool get isAdhaPanelOpen => _isAdhaPanelOpen;
  bool get isAdhaPanelFullscreen => _isAdhaPanelFullscreen;
  double get adhaPanelWidth => _adhaPanelWidth;

  void toggleSidebar() {
    _isSidebarExpanded = !_isSidebarExpanded;
    notifyListeners();
  }

  void setSidebarExpanded(bool expanded) {
    if (_isSidebarExpanded != expanded) {
      _isSidebarExpanded = expanded;
      notifyListeners();
    }
  }

  void openAdhaPanel() {
    _isAdhaPanelOpen = true;
    _isAdhaPanelFullscreen = false;
    notifyListeners();
  }

  void closeAdhaPanel() {
    _isAdhaPanelOpen = false;
    _isAdhaPanelFullscreen = false;
    notifyListeners();
  }

  void toggleAdhaPanel() {
    if (_isAdhaPanelOpen) {
      closeAdhaPanel();
    } else {
      openAdhaPanel();
    }
  }

  void toggleAdhaFullscreen() {
    _isAdhaPanelFullscreen = !_isAdhaPanelFullscreen;
    notifyListeners();
  }

  void setAdhaFullscreen(bool fullscreen) {
    if (_isAdhaPanelFullscreen != fullscreen) {
      _isAdhaPanelFullscreen = fullscreen;
      notifyListeners();
    }
  }

  void setAdhaPanelWidth(double width) {
    _adhaPanelWidth = width.clamp(minAdhaPanelWidth, maxAdhaPanelWidth);
    notifyListeners();
  }

  /// Auto-collapse sidebar when Adha panel is open to give more space
  void autoAdjustLayout() {
    if (_isAdhaPanelOpen && _isSidebarExpanded) {
      _isSidebarExpanded = false;
      notifyListeners();
    }
  }
}

/// Provider pour le state du layout desktop
class DesktopLayoutProvider extends InheritedNotifier<DesktopLayoutState> {
  const DesktopLayoutProvider({
    super.key,
    required DesktopLayoutState state,
    required super.child,
  }) : super(notifier: state);

  static DesktopLayoutState of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<DesktopLayoutProvider>();
    return provider!.notifier!;
  }

  static DesktopLayoutState? maybeOf(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<DesktopLayoutProvider>();
    return provider?.notifier;
  }
}

/// Widget de séparation redimensionnable style VS Code
class ResizableDivider extends StatefulWidget {
  final VoidCallback? onDragStart;
  final Function(double)? onDragUpdate;
  final VoidCallback? onDragEnd;
  final bool isVertical;
  final double thickness;

  const ResizableDivider({
    super.key,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.isVertical = true,
    this.thickness = 6.0,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Couleur subtile qui devient visible au hover
    final normalColor = Colors.transparent;
    final hoverColor = WanzoColors.primary.withValues(alpha: 0.5);
    final activeColor = WanzoColors.primary;

    return MouseRegion(
      cursor:
          widget.isVertical
              ? SystemMouseCursors.resizeColumn
              : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onHorizontalDragStart:
            widget.isVertical
                ? (_) {
                  setState(() => _isDragging = true);
                  widget.onDragStart?.call();
                }
                : null,
        onHorizontalDragUpdate:
            widget.isVertical
                ? (details) => widget.onDragUpdate?.call(details.delta.dx)
                : null,
        onHorizontalDragEnd:
            widget.isVertical
                ? (_) {
                  setState(() => _isDragging = false);
                  widget.onDragEnd?.call();
                }
                : null,
        onVerticalDragStart:
            !widget.isVertical
                ? (_) {
                  setState(() => _isDragging = true);
                  widget.onDragStart?.call();
                }
                : null,
        onVerticalDragUpdate:
            !widget.isVertical
                ? (details) => widget.onDragUpdate?.call(details.delta.dy)
                : null,
        onVerticalDragEnd:
            !widget.isVertical
                ? (_) {
                  setState(() => _isDragging = false);
                  widget.onDragEnd?.call();
                }
                : null,
        child: Container(
          width: widget.isVertical ? widget.thickness : null,
          height: !widget.isVertical ? widget.thickness : null,
          color:
              isDark
                  ? Colors.grey[800]?.withValues(alpha: 0.3)
                  : Colors.grey[300]?.withValues(alpha: 0.3),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.isVertical ? 2 : null,
              height: !widget.isVertical ? 2 : null,
              decoration: BoxDecoration(
                color:
                    _isDragging
                        ? activeColor
                        : (_isHovered ? hoverColor : normalColor),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Conteneur du panneau Adha avec header et contrôles
class AdhaPanelContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback? onClose;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;
  final String title;

  const AdhaPanelContainer({
    super.key,
    required this.child,
    this.onClose,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.title = 'Adha - Assistant IA',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(
            color:
                isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.5)
                    : Colors.grey[300]!.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header du panneau
          _buildPanelHeader(context, theme, isDark),

          // Contenu
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPanelHeader(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.grey[900]?.withValues(alpha: 0.5)
                : Colors.grey[100],
        border: Border(
          bottom: BorderSide(
            color:
                isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.5)
                    : Colors.grey[300]!.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icône chat
          Icon(Icons.chat_bubble_outline, size: 16, color: WanzoColors.primary),
          const SizedBox(width: 8),

          // Titre dynamique basé sur l'état Adha
          Expanded(
            child: BlocBuilder<AdhaBloc, AdhaState>(
              builder: (context, state) {
                String displayTitle = title;
                if (state is AdhaConversationActive) {
                  displayTitle =
                      state.conversation.title.isNotEmpty
                          ? state.conversation.title
                          : 'Nouvelle conversation';
                }
                return Text(
                  displayTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),

          // Boutons de contrôle
          _buildControlButton(
            context,
            icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            tooltip: isFullscreen ? 'Quitter plein écran' : 'Plein écran',
            onPressed: onToggleFullscreen,
          ),
          const SizedBox(width: 4),
          _buildControlButton(
            context,
            icon: Icons.close,
            tooltip: 'Fermer',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
