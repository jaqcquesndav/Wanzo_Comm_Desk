import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Widget affichant un message en cours de streaming.
///
/// Depuis l'optimisation desktop : PLUS d'effet typewriter local. Le texte
/// affiché est directement le `partialContent` déjà batché par le BLoC
/// (fenêtre de 60 ms). L'ancienne double animation (batch bloc + typewriter
/// widget) faisait apparaître le texte en retard et provoquait un effet de
/// saccade. On garde uniquement le curseur clignotant et le point pulsant.
///
/// Le contenu est rendu en markdown léger (MarkdownBody) — le MÊME rendu que
/// le message final pour le cas texte courant — afin d'éliminer le flash de
/// reformatage au moment où le streaming se fige en message définitif.
class StreamingMessageWidget extends StatelessWidget {
  /// Contenu partiel reçu jusqu'à présent
  final String partialContent;

  /// Indique si le streaming est terminé
  final bool isComplete;

  /// Étape agentique compacte en cours (« Lecture de la base de
  /// connaissance… », « Génération du document… »). Null = aucune étape.
  final String? toolStatus;

  /// Callback appelé quand l'utilisateur clique sur "Annuler"
  final VoidCallback? onCancel;

  const StreamingMessageWidget({
    super.key,
    required this.partialContent,
    this.isComplete = false,
    this.toolStatus,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF7F7F8);
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    final hasContent = partialContent.isNotEmpty;
    final showToolStatus =
        !isComplete && toolStatus != null && toolStatus!.isNotEmpty;

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
                    if (!isComplete) ...[
                      const SizedBox(width: 8),
                      const _PulsingDot(),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Étape agentique compacte (workflow tool_call / tool_result)
                if (showToolStatus) ...[
                  _buildToolStatus(context, textColor, isDark),
                  if (hasContent) const SizedBox(height: 8),
                ],
                // Contenu du message rendu en markdown léger, sans animation
                // locale : on affiche directement ce que le bloc a batché.
                if (hasContent)
                  MarkdownBody(
                    data: partialContent,
                    selectable: false,
                    shrinkWrap: true,
                    styleSheet: _streamingStyleSheet(context, textColor),
                  ),
                // Curseur clignotant tant que le streaming n'est pas terminé.
                if (!isComplete) ...[
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

  /// Ligne d'étape agentique compacte (icône + libellé), style discret.
  Widget _buildToolStatus(BuildContext context, Color textColor, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            toolStatus!,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: textColor.withAlpha((0.7 * 255).round()),
            ),
          ),
        ),
      ],
    );
  }

  /// Feuille de style markdown légère alignée sur le rendu texte final
  /// (mêmes tailles/interlignes que ChatMessageWidget pour éviter le flash).
  MarkdownStyleSheet _streamingStyleSheet(
    BuildContext context,
    Color textColor,
  ) {
    return MarkdownStyleSheet(
      p: TextStyle(color: textColor, fontSize: 15, height: 1.6),
      strong: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
      listBullet: TextStyle(color: textColor, fontSize: 15),
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
