import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../bloc/adha_bloc.dart';
import '../bloc/adha_event.dart';
import '../bloc/adha_state.dart';
import '../../../core/utils/logger.dart';

/// Widget pour la reconnaissance vocale
class VoiceRecognitionWidget extends StatefulWidget {
  const VoiceRecognitionWidget({super.key});

  @override
  State<VoiceRecognitionWidget> createState() => _VoiceRecognitionWidgetState();
}

class _VoiceRecognitionWidgetState extends State<VoiceRecognitionWidget>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String _recognizedText = '';
  double _confidence = 0.0;
  
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    
    // Animation pour l'indicateur d'écoute
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Initialise le service de reconnaissance vocale
  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) => Logger.error('Erreur de reconnaissance vocale', error: error),
    );
    setState(() {});
  }

  /// Gère les changements d'état de la reconnaissance vocale
  void _onSpeechStatus(String status) {
    Logger.debug('Status de la reconnaissance vocale: $status');
    if (status == 'done' && _recognizedText.isNotEmpty) {
      // Envoie le texte reconnu à Adha
      context.read<AdhaBloc>().add(SendMessage(_recognizedText));
      setState(() {
        _recognizedText = '';
      });
    }
  }

  /// Gère le résultat de la reconnaissance vocale
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _recognizedText = result.recognizedWords;
      _confidence = result.confidence;
    });
  }

  /// Démarre la reconnaissance vocale
  void _startListening() async {
    if (_speechEnabled) {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
        ),
        localeId: 'fr_FR', // Langue française
      );
      
      setState(() {});
    } else {
      // La reconnaissance vocale n'est pas disponible
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La reconnaissance vocale n\'est pas disponible sur votre appareil.'),
        ),
      );
      
      // Désactive la reconnaissance vocale dans le bloc
      context.read<AdhaBloc>().add(const StopVoiceRecognition());
    }
  }

  /// Arrête la reconnaissance vocale
  void _stopListening() async {
    await _speech.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdhaBloc, AdhaState>(
      listener: (context, state) {
        if (state is AdhaConversationActive) {
          if (state.isVoiceActive && !_speech.isListening) {
            _startListening();
          } else if (!state.isVoiceActive && _speech.isListening) {
            _stopListening();
          }
        }
      },
      builder: (context, state) {
        final isVoiceActive = state is AdhaConversationActive && state.isVoiceActive;
        
        if (!isVoiceActive) {
          return const SizedBox.shrink();
        }
        
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
              // Texte reconnu
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
              
              // Indicateur d'écoute
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
                      child: const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 32,
                      ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Bouton pour arrêter l'écoute
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
      },
    );
  }
}
