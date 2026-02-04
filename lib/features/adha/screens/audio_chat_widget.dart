import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../utils/theme.dart';
import '../bloc/adha_bloc.dart';
import '../bloc/adha_event.dart';
import '../bloc/adha_state.dart';

/// Widget moderne pour l'interface audio full-duplex avec Adha (Style Gemini/Claude)
///
/// Caractéristiques v2.4.0:
/// - Animations fluides et subtiles
/// - Indicateurs visuels discrets
/// - UX simplifiée comme Claude/Gemini
class AudioChatWidget extends StatefulWidget {
  const AudioChatWidget({super.key});

  @override
  State<AudioChatWidget> createState() => _AudioChatWidgetState();
}

class _AudioChatWidgetState extends State<AudioChatWidget>
    with TickerProviderStateMixin {
  late AnimationController _waveAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _waveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Animation de pulsation subtile pour l'état d'écoute
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<AdhaBloc, AdhaState>(
      listener: (context, state) {
        // Gestion des effets de bord si nécessaire
      },
      builder: (context, state) {
        final bool isConversationActive = state is AdhaConversationActive;

        return Container(
          padding: EdgeInsets.only(
            left: WanzoTheme.spacingLg,
            right: WanzoTheme.spacingLg,
            top: WanzoTheme.spacingMd,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + WanzoTheme.spacingLg,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(WanzoTheme.borderRadiusXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle du modal - style minimal
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: WanzoTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // En-tête minimaliste style Claude
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ADHA',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Visualiseur Wave style Gemini/Claude
              if (isConversationActive)
                _buildModernWaveVisualizer(state)
              else
                _buildIdleState(context),

              const SizedBox(height: 24),

              // Status text subtil
              if (isConversationActive) _buildStatusIndicator(state),

              const Spacer(),

              // Contrôles simplifiés style Claude
              _buildModernControls(context, state, isConversationActive),

              const SizedBox(height: WanzoTheme.spacingLg),
            ],
          ),
        );
      },
    );
  }

  String _getStatusText(AdhaConversationActive state) {
    if (state.isProcessing) return "Réflexion en cours...";
    if (state.isAdhaPlaying) return "ADHA parle";
    if (state.isRecording) return "Je vous écoute";
    return "Prêt à écouter";
  }

  Widget _buildStatusIndicator(AdhaConversationActive state) {
    final statusText = _getStatusText(state);
    final isActive =
        state.isRecording || state.isAdhaPlaying || state.isProcessing;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isActive ? 1.0 : 0.6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            _AnimatedStatusDot(
              color:
                  state.isRecording
                      ? WanzoTheme.error
                      : (state.isAdhaPlaying
                          ? Colors.blue
                          : WanzoTheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Visualiseur d'ondes moderne style Gemini
  Widget _buildModernWaveVisualizer(AdhaConversationActive state) {
    return SizedBox(
      height: 100,
      child: AnimatedBuilder(
        animation: _waveAnimationController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(5, (index) {
              double animationValue = _waveAnimationController.value;
              double offset = index * (math.pi / 2.5);

              // Activité basée sur l'état
              double activity = 0.15; // Base respiration subtile
              if (state.isRecording) {
                activity = 0.4 + (state.audioLevel * 0.6);
              } else if (state.isAdhaPlaying) {
                activity = 0.5;
              } else if (state.isProcessing) {
                activity = 0.35;
              }

              // Calcul de la hauteur avec onde sinusoïdale douce
              double wave = math.sin((animationValue * 2 * math.pi) + offset);
              double height = 20 + (wave * 25 * activity) + (activity * 35);

              // Couleurs dynamiques subtiles
              Color barColor;
              if (state.isRecording) {
                barColor =
                    Color.lerp(
                      const Color(0xFFEF4444),
                      const Color(0xFFF97316),
                      index / 4,
                    ) ??
                    const Color(0xFFEF4444);
              } else if (state.isAdhaPlaying) {
                barColor =
                    Color.lerp(
                      const Color(0xFF3B82F6),
                      const Color(0xFF06B6D4),
                      index / 4,
                    ) ??
                    const Color(0xFF3B82F6);
              } else if (state.isProcessing) {
                barColor = const Color(0xFFA855F7).withValues(alpha: 0.8);
              } else {
                barColor = Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.25);
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 16,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow:
                      activity > 0.3
                          ? [
                            BoxShadow(
                              color: barColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                          : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildIdleState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mic_none_rounded,
            size: 28,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Mode audio inactif",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  /// Contrôles modernes style Claude/Gemini
  Widget _buildModernControls(
    BuildContext context,
    AdhaState state,
    bool isConversationActive,
  ) {
    bool isRecording = false;
    bool isPlaying = false;

    if (state is AdhaConversationActive) {
      isRecording = state.isRecording;
      isPlaying = state.isAdhaPlaying;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bouton retour au clavier - discret
        _buildSecondaryButton(
          icon: Icons.keyboard_alt_outlined,
          tooltip: "Clavier",
          onPressed: () => Navigator.of(context).pop(),
        ),

        const SizedBox(width: 24),

        // Bouton principal avec animation de pulsation
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isRecording ? _pulseAnimation.value : 1.0,
              child: _buildMainButton(
                context: context,
                isRecording: isRecording,
                isPlaying: isPlaying,
                isConversationActive: isConversationActive,
                onTap: () {
                  if (isConversationActive) {
                    if (isPlaying) {
                      context.read<AdhaBloc>().add(const InterruptAdha());
                    } else {
                      context.read<AdhaBloc>().add(
                        ToggleRecording(!isRecording),
                      );
                    }
                  }
                },
              ),
            );
          },
        ),

        const SizedBox(width: 24),

        // Bouton quitter - discret
        _buildSecondaryButton(
          icon: Icons.call_end_rounded,
          tooltip: "Quitter",
          color: WanzoTheme.error,
          onPressed: () {
            if (isConversationActive) {
              context.read<AdhaBloc>().add(const EndAudioSession());
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 22,
            color:
                color ??
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton({
    required BuildContext context,
    required bool isRecording,
    required bool isPlaying,
    required bool isConversationActive,
    required VoidCallback onTap,
  }) {
    Color bgColor;
    IconData iconData;
    Color iconColor = Colors.white;

    if (isPlaying) {
      bgColor = Colors.white;
      iconData = Icons.stop_rounded;
      iconColor = const Color(0xFF3B82F6);
    } else if (isRecording) {
      bgColor = WanzoTheme.error;
      iconData = Icons.mic;
    } else {
      bgColor = WanzoTheme.primary;
      iconData = Icons.mic_none_rounded;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border:
              isPlaying
                  ? Border.all(color: const Color(0xFF3B82F6), width: 2)
                  : null,
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(iconData, color: iconColor, size: 28),
      ),
    );
  }
}

/// Point d'état animé
class _AnimatedStatusDot extends StatefulWidget {
  final Color color;

  const _AnimatedStatusDot({required this.color});

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
