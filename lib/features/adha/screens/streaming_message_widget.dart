import 'package:flutter/material.dart';

/// Widget affichant un message en cours de streaming avec effet typewriter
/// Style inspiré de Claude/ChatGPT avec affichage progressif du texte
class StreamingMessageWidget extends StatefulWidget {
  /// Contenu partiel reçu jusqu'à présent
  final String partialContent;

  /// Indique si le streaming est terminé
  final bool isComplete;

  /// Callback appelé quand l'utilisateur clique sur "Annuler"
  final VoidCallback? onCancel;

  const StreamingMessageWidget({
    super.key,
    required this.partialContent,
    this.isComplete = false,
    this.onCancel,
  });

  @override
  State<StreamingMessageWidget> createState() => _StreamingMessageWidgetState();
}

class _StreamingMessageWidgetState extends State<StreamingMessageWidget> {
  /// Texte actuellement affiché (peut être en retard par rapport à partialContent)
  String _displayedText = '';

  /// Index du dernier caractère affiché
  int _currentIndex = 0;

  /// Contrôleur pour l'animation typewriter
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _startTypewriterEffect();
  }

  @override
  void didUpdateWidget(StreamingMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si nouveau contenu arrive, continuer l'animation
    if (widget.partialContent.length > _displayedText.length) {
      _startTypewriterEffect();
    }
  }

  void _startTypewriterEffect() {
    if (_isAnimating) return;
    _isAnimating = true;
    _animateNextCharacters();
  }

  void _animateNextCharacters() async {
    while (mounted && _currentIndex < widget.partialContent.length) {
      // Calculer combien de caractères ajouter
      // Vitesse adaptative : plus rapide pour rattraper, plus lent pour l'effet
      final remaining = widget.partialContent.length - _currentIndex;
      final charsToAdd = remaining > 50 ? 5 : (remaining > 20 ? 3 : 1);

      final endIndex = (_currentIndex + charsToAdd).clamp(
        0,
        widget.partialContent.length,
      );

      setState(() {
        _displayedText = widget.partialContent.substring(0, endIndex);
        _currentIndex = endIndex;
      });

      // Délai entre les caractères (effet typewriter)
      // Plus rapide si beaucoup de texte en attente, plus lent sinon
      final delay = remaining > 50 ? 5 : (remaining > 20 ? 15 : 25);
      await Future.delayed(Duration(milliseconds: delay));
    }
    _isAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF7F7F8);
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom ADHA avec indicateur de streaming subtil
                Row(
                  children: [
                    Text(
                      'ADHA',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    if (!widget.isComplete) ...[
                      const SizedBox(width: 8),
                      const _PulsingDot(),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Contenu du message avec effet typewriter
                if (_displayedText.isNotEmpty)
                  Text(
                    _displayedText,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                // Indicateur de saisie si le streaming n'est pas complet
                if (!widget.isComplete) ...[
                  const SizedBox(height: 8),
                  const _StreamingCursor(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
    );
  }
}

/// Point pulsant subtil pour indiquer l'activité (style Gemini)
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(
              context,
            ).primaryColor.withAlpha((_animation.value * 255).round()),
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

/// Curseur de streaming animé (style machine à écrire subtil)
class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            width: 2,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(1),
            ),
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

/// Indicateur de saisie animé (trois points) - Style classique
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Créer des animations décalées pour chaque point
    _dotAnimations = List.generate(3, (index) {
      final start = index * 0.2;
      final end = start + 0.4;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final animation = _dotAnimations[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -4 * animation.value),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withAlpha(
                      ((0.4 + 0.6 * animation.value) * 255).round(),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
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

/// Widget pour afficher l'état de connexion au streaming
class StreamConnectionIndicator extends StatelessWidget {
  /// Indique si connecté au service de streaming
  final bool isConnected;

  /// Indique si en cours de connexion
  final bool isConnecting;

  /// Message d'erreur éventuel
  final String? errorMessage;

  const StreamConnectionIndicator({
    super.key,
    required this.isConnected,
    this.isConnecting = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 14, color: Colors.red[700]),
            const SizedBox(width: 4),
            Text(
              'Erreur de connexion',
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
            ),
          ],
        ),
      );
    }

    if (isConnecting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Connexion...',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
          ],
        ),
      );
    }

    if (isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: Colors.green[700],
            ),
            const SizedBox(width: 4),
            Text(
              'Streaming actif',
              style: TextStyle(fontSize: 12, color: Colors.green[700]),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Widget affichant "ADHA est en train d'écrire..." avec animation subtile
class AdhaTypingBanner extends StatelessWidget {
  const AdhaTypingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          const _PulsingDot(),
          const SizedBox(width: 8),
          Text(
            'ADHA génère une réponse...',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withAlpha((0.7 * 255).round()),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
