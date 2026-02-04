import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/adha_bloc.dart';
import '../bloc/adha_event.dart';
import '../bloc/adha_state.dart';
import '../../../core/platform/platform_service.dart';
import '../../../core/platform/speech/speech_service_factory.dart';
import '../../../core/utils/logger.dart';

/// Widget adaptatif pour la saisie vocale/texte selon la plateforme
/// Sur mobile: reconnaissance vocale via microphone
/// Sur desktop: saisie texte rapide avec raccourcis clavier
class AdaptiveVoiceInputWidget extends StatefulWidget {
  const AdaptiveVoiceInputWidget({super.key});

  @override
  State<AdaptiveVoiceInputWidget> createState() =>
      _AdaptiveVoiceInputWidgetState();
}

class _AdaptiveVoiceInputWidgetState extends State<AdaptiveVoiceInputWidget>
    with SingleTickerProviderStateMixin {
  final _speechService = SpeechServiceFactory.getInstance();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  bool _speechSupported = false;
  bool _isInitialized = false;
  String _recognizedText = '';
  double _confidence = 0.0;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _checkSpeechSupport();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }

  Future<void> _checkSpeechSupport() async {
    _speechSupported = await _speechService.isSupported();
    if (_speechSupported) {
      _isInitialized = await _speechService.initialize();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _speechService.dispose();
    super.dispose();
  }

  void _startListening() async {
    if (!_speechSupported || !_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La reconnaissance vocale n\'est pas disponible. Utilisez la saisie texte.',
          ),
        ),
      );
      context.read<AdhaBloc>().add(const StopVoiceRecognition());
      return;
    }

    await _speechService.startListening(
      onResult: (text, confidence) {
        setState(() {
          _recognizedText = text;
          _confidence = confidence;
        });
      },
      onStatus: (status) {
        Logger.debug('Speech status: $status');
        if (status == 'done' && _recognizedText.isNotEmpty) {
          context.read<AdhaBloc>().add(SendMessage(_recognizedText));
          setState(() => _recognizedText = '');
        }
      },
      onError: (error) {
        Logger.error('Speech error: $error');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $error')));
      },
    );
  }

  void _stopListening() async {
    await _speechService.stopListening();
    setState(() {});
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      context.read<AdhaBloc>().add(SendMessage(text));
      _textController.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = PlatformService.instance;

    return BlocConsumer<AdhaBloc, AdhaState>(
      listener: (context, state) {
        if (state is AdhaConversationActive) {
          if (state.isVoiceActive &&
              !_speechService.isListening &&
              _speechSupported) {
            _startListening();
          } else if (!state.isVoiceActive && _speechService.isListening) {
            _stopListening();
          }
        }
      },
      builder: (context, state) {
        final isVoiceActive =
            state is AdhaConversationActive && state.isVoiceActive;

        // Sur desktop ou si la voix n'est pas supportée, afficher le widget texte
        if (platform.isDesktop || !_speechSupported) {
          return _buildDesktopTextInput(context);
        }

        // Sur mobile avec support vocal
        if (!isVoiceActive) {
          return const SizedBox.shrink();
        }

        return _buildMobileVoiceWidget(context);
      },
    );
  }

  Widget _buildDesktopTextInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Posez votre question à Adha...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                  onPressed: _sendTextMessage,
                ),
              ),
              onSubmitted: (_) => _sendTextMessage(),
              textInputAction: TextInputAction.send,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileVoiceWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_recognizedText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _recognizedText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _animation,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple.shade700,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "J'écoute...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Confiance: ${(_confidence * 100).toStringAsFixed(1)}%",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () {
              context.read<AdhaBloc>().add(const StopVoiceRecognition());
            },
            icon: const Icon(Icons.stop),
            label: const Text("Arrêter"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
