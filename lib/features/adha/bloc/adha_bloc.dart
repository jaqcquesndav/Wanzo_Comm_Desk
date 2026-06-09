import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert'; // base64Encode pour le WAV silencieux du greeting
import '../../../core/services/api_client.dart';
import '../repositories/adha_repository.dart';
import '../../auth/repositories/auth_repository.dart'; // Corrected path
import '../../dashboard/repositories/operation_journal_repository.dart'; // Corrected path
import '../../auth/models/user.dart'; // For User model
import '../services/audio_streaming_service.dart'
    as audio_service; // Pour le service audio
import '../services/adha_stream_service.dart'; // Pour le service de streaming
import '../models/adha_stream_models.dart'; // Pour les modèles de streaming
// For OperationJournalEntry model

import 'adha_event.dart';
import 'adha_state.dart';
import '../models/adha_message.dart';
import '../models/adha_context_info.dart';
import '../../../core/services/business_context_service.dart';

/// BLoC pour gérer l'interaction avec l'assistant Adha
class AdhaBloc extends Bloc<AdhaEvent, AdhaState> {
  final AdhaRepository adhaRepository;
  final AuthRepository authRepository;
  final OperationJournalRepository operationJournalRepository;
  final audio_service.AudioStreamingService _audioStreamingService;
  final AdhaStreamService _streamService; // Service de streaming
  final _uuid = const Uuid();
  String? _currentlyActiveConversationId; // Added to track active conversation

  // Subscriptions pour les streams audio
  StreamSubscription? _audioConnectionSubscription;
  StreamSubscription? _audioLevelSubscription;
  StreamSubscription? _isRecordingSubscription;
  StreamSubscription? _isPlayingSubscription;

  // Subscriptions pour le streaming de réponses
  StreamSubscription<AdhaStreamChunkEvent>? _streamChunkSubscription;
  StreamSubscription<AdhaStreamConnectionState>? _streamConnectionSubscription;
  // Subscription pour les chunks audio TTS (v3.0)
  StreamSubscription? _ttsAudioChunkSubscription;

  // Buffer pour accumuler le contenu de streaming
  final StringBuffer _accumulatedStreamContent = StringBuffer();
  String? _currentStreamingRequestId;

  // Flag de session audio active (mirroir du mobile). Permet aux callbacks
  // VAD/silence d'éviter de relancer l'écoute après EndAudioSession.
  bool _isAudioSessionActive = false;

  // ──────────────────────────────────────────────────────────────────────
  // Chunk batching pour fluidité du rendu (Phase 2D)
  // ──────────────────────────────────────────────────────────────────────
  // Plutôt que d'émettre StreamChunkReceived à chaque mini-chunk reçu du
  // backend (50-200/s sur GPT-4o), on accumule les chunks pendant une
  // fenêtre courte et on émet une seule fois par fenêtre. Réduit les
  // rebuilds du widget de streaming sans changer le contenu final.
  //
  // Stratégie hybride : flush au plus tard après _chunkBatchWindowMs OU si
  // le buffer dépasse _chunkBatchMaxChars. StreamEnd/StreamError flushent
  // immédiatement pour ne perdre aucun chunk.
  static const int _chunkBatchWindowMs = 60;
  static const int _chunkBatchMaxChars = 200;
  final StringBuffer _chunkBatchBuffer = StringBuffer();
  int _chunkBatchLatestChunkId = 0;
  String _chunkBatchConversationId = '';
  String _chunkBatchRequestMessageId = '';
  Timer? _chunkBatchTimer;

  AdhaBloc({
    required this.adhaRepository,
    required this.authRepository,
    required this.operationJournalRepository,
    audio_service.AudioStreamingService? audioStreamingService,
    AdhaStreamService? streamService,
  }) : _audioStreamingService =
           audioStreamingService ?? audio_service.AudioStreamingService(),
       _streamService = streamService ?? AdhaStreamService(),
       super(const AdhaInitial()) {
    _currentlyActiveConversationId = null; // Explicitly null at start

    // Événements existants
    on<SendMessage>(_onSendMessage);
    on<LoadConversations>(_onLoadConversations);
    on<LoadConversation>(_onLoadConversation);
    on<NewConversation>(_onNewConversation);
    on<DeleteConversation>(_onDeleteConversation);
    on<StartVoiceRecognition>(_onStartVoiceRecognition);
    on<StopVoiceRecognition>(_onStopVoiceRecognition);
    on<EditMessage>(_onEditMessage);

    // Nouveaux événements audio
    on<StartAudioSession>(_onStartAudioSession);
    on<EndAudioSession>(_onEndAudioSession);
    on<ToggleRecording>(_onToggleRecording);
    on<InterruptAdha>(_onInterruptAdha);
    on<SetAudioVolume>(_onSetAudioVolume);
    on<AudioStateUpdate>(_onAudioStateUpdate);

    // Événements de streaming (Janvier 2026)
    on<ConnectToStreamService>(_onConnectToStreamService);
    on<DisconnectFromStreamService>(_onDisconnectFromStreamService);
    on<SendStreamingMessage>(_onSendStreamingMessage);
    on<StreamChunkReceived>(_onStreamChunkReceived);
    on<StreamCompleted>(_onStreamCompleted);
    on<StreamError>(_onStreamError);
    on<CancelStreaming>(_onCancelStreaming);

    // Événements de gestion de session
    on<ClearCurrentConversation>(_onClearCurrentConversation);
    on<InitializeForUser>(_onInitializeForUser);

    // Initialiser les listeners pour le service audio
    _initAudioListeners();

    // Initialiser les listeners pour le streaming
    _initStreamListeners();
  }

  /// Map audio service connection state to BLoC state
  AudioConnectionState _mapServiceToStateConnectionState(
    audio_service.AudioConnectionState serviceState,
  ) {
    switch (serviceState) {
      case audio_service.AudioConnectionState.disconnected:
        return AudioConnectionState.disconnected;
      case audio_service.AudioConnectionState.connecting:
        return AudioConnectionState.connecting;
      case audio_service.AudioConnectionState.connected:
        return AudioConnectionState.connected;
      case audio_service.AudioConnectionState.ready:
        return AudioConnectionState.ready;
      case audio_service.AudioConnectionState.error:
        return AudioConnectionState.error;
    }
  }

  // Helper to build AdhaContextInfo with the new structured models
  Future<AdhaContextInfo> _buildContextInfo(
    AdhaInteractionType interactionType, {
    String? sourceIdentifier,
    Map<String, dynamic>? interactionData,
    String?
    conversationId, // Optional: to determine if it's a follow-up if not explicitly set
  }) async {
    debugPrint(
      '[AdhaBloc] _buildContextInfo: interactionType=$interactionType',
    );
    debugPrint(
      '[AdhaBloc] _buildContextInfo: sourceIdentifier=$sourceIdentifier',
    );
    debugPrint('[AdhaBloc] _buildContextInfo: conversationId=$conversationId');

    // 1. Fetch Business Profile
    AdhaBusinessProfile businessProfile;
    try {
      final User? currentUser = await authRepository.getCurrentUser();
      debugPrint(
        '[AdhaBloc] _buildContextInfo: currentUser=${currentUser?.name}',
      );
      debugPrint(
        '[AdhaBloc] _buildContextInfo: currentUser.companyName=${currentUser?.companyName}',
      );
      debugPrint(
        '[AdhaBloc] _buildContextInfo: currentUser.companyId=${currentUser?.companyId}',
      );
      if (currentUser != null) {
        businessProfile = AdhaBusinessProfile(
          name: currentUser.companyName ?? 'Entreprise',
          sector: currentUser.businessSector,
          address: currentUser.companyLocation,
          additionalInfo: {
            'rccmNumber': currentUser.rccmNumber,
            'contactName': currentUser.name,
            'contactEmail': currentUser.email,
            'contactPhone': currentUser.phone,
          },
        );
      } else {
        businessProfile = const AdhaBusinessProfile(
          name: 'Wanzo Demo Business (Default)',
          sector: 'N/A',
        );
      }
    } catch (e) {
      debugPrint('Error fetching business profile for Adha context: $e');
      businessProfile = const AdhaBusinessProfile(
        name: 'Error Fetching Profile',
        sector: 'Error',
      );
    }

    // 2. Fetch Operation Journal Summary
    AdhaOperationJournalSummary operationJournalSummary;
    try {
      final recentEntries = await operationJournalRepository.getRecentEntries(
        limit: 5,
      );

      // Convertir les entrées du journal en AdhaOperationJournalEntry
      final adhaEntries =
          recentEntries
              .map(
                (entry) => AdhaOperationJournalEntry(
                  timestamp:
                      entry['timestamp']?.toString() ??
                      DateTime.now().toIso8601String(),
                  description: entry['description']?.toString() ?? '',
                  operationType:
                      entry['operationType']?.toString() ?? 'UNKNOWN',
                  details: entry['details'] as Map<String, dynamic>?,
                ),
              )
              .toList();

      operationJournalSummary = AdhaOperationJournalSummary(
        recentEntries: adhaEntries,
      );
    } catch (e) {
      debugPrint(
        'Error fetching operation journal summary for Adha context: $e',
      );
      operationJournalSummary = const AdhaOperationJournalSummary(
        recentEntries: [],
      );
    }

    final baseContext = AdhaBaseContext(
      operationJournalSummary: operationJournalSummary,
      businessProfile: businessProfile,
    );

    debugPrint(
      '[AdhaBloc] _buildContextInfo: businessProfile.name=${businessProfile.name}',
    );
    debugPrint(
      '[AdhaBloc] _buildContextInfo: operationJournalSummary.recentEntries.length=${operationJournalSummary.recentEntries.length}',
    );

    // Déterminer le type d'interaction final
    AdhaInteractionType finalInteractionType = interactionType;
    if (conversationId != null &&
        interactionType != AdhaInteractionType.genericCardAnalysis) {
      finalInteractionType = AdhaInteractionType.followUp;
    }

    debugPrint(
      '[AdhaBloc] _buildContextInfo: finalInteractionType=$finalInteractionType',
    );

    final interactionContext = AdhaInteractionContext(
      interactionType: finalInteractionType,
      sourceIdentifier: sourceIdentifier,
      interactionData: interactionData,
    );

    final contextInfo = AdhaContextInfo(
      baseContext: baseContext,
      interactionContext: interactionContext,
    );

    // Log the final context JSON
    debugPrint('[AdhaBloc] _buildContextInfo: FINAL CONTEXT JSON:');
    debugPrint('[AdhaBloc] ${contextInfo.toJson()}');

    return contextInfo;
  }

  /// Gère l'envoi d'un message à Adha
  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<AdhaState> emit,
  ) async {
    AdhaConversation currentConversation;
    AdhaContextInfo contextInfoForApi;
    AdhaConversationActive? previousState =
        state is AdhaConversationActive
            ? (state as AdhaConversationActive)
            : null;

    // Déterminer si c'est une nouvelle conversation ou une existante
    // NOUVEAU (Janvier 2026): Le frontend génère toujours le conversationId
    // pour permettre une meilleure traçabilité et cohérence avec le mode streaming.
    bool isNewConversation = false;
    String? conversationIdForApi;

    if (state is AdhaConversationActive) {
      final currentState = state as AdhaConversationActive;
      currentConversation = currentState.conversation;
      conversationIdForApi = currentConversation.id; // Conversation existante
      contextInfoForApi = await _buildContextInfo(
        event.contextInfo?.interactionContext.interactionType ??
            AdhaInteractionType.followUp,
        sourceIdentifier:
            event.contextInfo?.interactionContext.sourceIdentifier,
        interactionData: event.contextInfo?.interactionContext.interactionData,
        conversationId: currentConversation.id,
      );
    } else {
      if (event.contextInfo == null) {
        emit(
          const AdhaError(
            "ContextInfo est requis pour démarrer une nouvelle conversation.",
          ),
        );
        return;
      }
      isNewConversation = true;
      // NOUVEAU: Le frontend génère le conversationId (UUID)
      // et l'envoie au backend pour cohérence avec le mode streaming
      final clientGeneratedConversationId = _uuid.v4();
      conversationIdForApi = clientGeneratedConversationId;
      debugPrint(
        '[AdhaBloc] 🆕 SendMessage - ID généré côté client: $clientGeneratedConversationId',
      );
      currentConversation = AdhaConversation(
        id: clientGeneratedConversationId,
        title: _generateConversationTitle(event.message),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
      contextInfoForApi = await _buildContextInfo(
        event.contextInfo!.interactionContext.interactionType,
        sourceIdentifier:
            event.contextInfo!.interactionContext.sourceIdentifier,
        interactionData: event.contextInfo!.interactionContext.interactionData,
        conversationId: clientGeneratedConversationId,
      );
    }

    final userMessage = AdhaMessage(
      id: _uuid.v4(),
      content: event.message,
      timestamp: DateTime.now(),
      sender: AdhaMessageSender.user,
    );

    final updatedMessages = List<AdhaMessage>.from(currentConversation.messages)
      ..add(userMessage);
    final updatedConversationWithUserMsg = currentConversation.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    emit(
      AdhaConversationActive(
        conversation: updatedConversationWithUserMsg,
        isProcessing: true,
        isVoiceActive: previousState?.isVoiceActive ?? false,
      ),
    );

    try {
      // Envoyer au backend avec le conversationId généré côté client
      final response = await adhaRepository.sendMessage(
        conversationId: conversationIdForApi, // ID généré côté client
        message: event.message,
        contextInfo: contextInfoForApi,
      );

      // Vérifier si le backend a utilisé l'ID fourni (nouveau comportement)
      // ou s'il a généré un nouvel ID (ancien comportement - compatibilité)
      if (isNewConversation &&
          response.conversationId.isNotEmpty &&
          response.conversationId != conversationIdForApi) {
        debugPrint(
          '[AdhaBloc] ⚠️ Backend a retourné un ID différent: ${response.conversationId} vs $conversationIdForApi',
        );
        currentConversation = currentConversation.copyWith(
          id: response.conversationId,
        );
        // Mettre à jour aussi la conversation avec le message utilisateur
        final updatedWithBackendId = updatedConversationWithUserMsg.copyWith(
          id: response.conversationId,
        );
        updatedMessages.clear();
        updatedMessages.addAll(updatedWithBackendId.messages);
      } else if (isNewConversation) {
        debugPrint(
          '[AdhaBloc] ✅ Backend a accepté l\'ID client: $conversationIdForApi',
        );
      }

      final adhaMessage = AdhaMessage(
        id: _uuid.v4(),
        content: response.content,
        timestamp: DateTime.now(),
        sender: AdhaMessageSender.ai,
        type: _detectMessageType(response.content),
      );

      final finalMessages = List<AdhaMessage>.from(updatedMessages)
        ..add(adhaMessage);
      final finalConversation = currentConversation.copyWith(
        messages: finalMessages,
        updatedAt: DateTime.now(),
      );

      await adhaRepository.saveConversation(finalConversation);
      _currentlyActiveConversationId = finalConversation.id; // Set active ID

      emit(
        AdhaConversationActive(
          conversation: finalConversation,
          isProcessing: false,
          isVoiceActive: previousState?.isVoiceActive ?? false,
        ),
      );
    } on AdhaServiceException catch (e) {
      // Gestion spécifique des erreurs du service ADHA
      emit(AdhaError(e.message));
      if (previousState != null) {
        emit(previousState.copyWith(isProcessing: false));
      } else {
        emit(
          AdhaConversationActive(
            conversation: updatedConversationWithUserMsg,
            isProcessing: false,
            isVoiceActive: false,
          ),
        );
      }
    } catch (e) {
      emit(AdhaError("Erreur lors de l'envoi du message: $e"));
      if (previousState != null) {
        emit(previousState.copyWith(isProcessing: false));
      } else {
        // If there was no previous active state, emit a new one based on current conversation
        emit(
          AdhaConversationActive(
            conversation:
                updatedConversationWithUserMsg, // or currentConversation if preferred
            isProcessing: false,
            isVoiceActive: false,
          ),
        );
      }
    }
  }

  Future<void> _onNewConversation(
    NewConversation event,
    Emitter<AdhaState> emit,
  ) async {
    // If the initial message is empty and the source is the new conversation button,
    // or more generally, if we want to reset to the initial suggestion view.
    if (event.initialMessage.isEmpty &&
        event.contextInfo.interactionContext.sourceIdentifier ==
            'new_conversation_button') {
      _currentlyActiveConversationId = null; // Clear active ID
      emit(const AdhaInitial());
      // Optionally, if you want to ensure a default "empty" conversation is ready in the background
      // you could load conversations which might create one if none exist.
      // add(const LoadConversations());
      return;
    }

    emit(const AdhaLoading());
    AdhaConversationActive? previousState =
        state is AdhaConversationActive
            ? (state as AdhaConversationActive)
            : null;
    try {
      final newConversationId = _uuid.v4();
      final userMessage = AdhaMessage(
        id: _uuid.v4(),
        content: event.initialMessage,
        timestamp: DateTime.now(),
        sender: AdhaMessageSender.user,
      );

      final contextInfoForApi = await _buildContextInfo(
        event.contextInfo.interactionContext.interactionType,
        sourceIdentifier: event.contextInfo.interactionContext.sourceIdentifier,
        interactionData: event.contextInfo.interactionContext.interactionData,
      );

      AdhaConversation newConversation = AdhaConversation(
        id: newConversationId,
        title: _generateConversationTitle(event.initialMessage),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages:
            event.initialMessage.isNotEmpty
                ? [userMessage]
                : [], // Ensure messages list is empty if initialMessage is empty
      );

      // If initialMessage is empty, we might not want to immediately process.
      // The AdhaInitial state should be shown.
      // However, the current structure proceeds to send a message.
      // This part might need review if an empty initialMessage is truly intended for _onNewConversation
      // beyond just resetting to AdhaInitial via the button.
      // For now, assuming if initialMessage is not empty, we proceed.

      if (event.initialMessage.isEmpty) {
        // This case should ideally be fully handled by the AdhaInitial emission above
        // if the intent is just to go to suggestions.
        // If a "new blank conversation" is to be created and made active without a message,
        // then _currentlyActiveConversationId should be set.
        // For now, the button press path (empty message) clears the ID and emits AdhaInitial.
        // If this event is called with an empty message NOT from the button,
        // it implies creating a blank, active conversation.
        if (event.contextInfo.interactionContext.sourceIdentifier !=
            'new_conversation_button') {
          await adhaRepository.saveConversation(newConversation);
          _currentlyActiveConversationId = newConversation.id;
          emit(
            AdhaConversationActive(
              conversation: newConversation,
              isProcessing: false,
            ),
          );
        }
        return;
      }

      // Proceed if initialMessage is not empty
      emit(
        AdhaConversationActive(
          conversation: newConversation,
          isProcessing: true,
          isVoiceActive: previousState?.isVoiceActive ?? false,
        ),
      );

      // Pour une nouvelle conversation, ne pas envoyer de conversationId
      final response = await adhaRepository.sendMessage(
        conversationId: null, // Le backend créera la conversation
        message: event.initialMessage,
        contextInfo: contextInfoForApi,
      );

      // Mettre à jour la conversation avec l'ID du backend
      final conversationWithBackendId = newConversation.copyWith(
        id:
            response.conversationId.isNotEmpty
                ? response.conversationId
                : newConversationId,
      );

      final adhaMessage = AdhaMessage(
        id: _uuid.v4(),
        content: response.content,
        timestamp: DateTime.now(),
        sender: AdhaMessageSender.ai,
        type: _detectMessageType(response.content),
      );

      final updatedConversationWithResponse = conversationWithBackendId
          .copyWith(
            messages: List<AdhaMessage>.from(conversationWithBackendId.messages)
              ..add(adhaMessage),
            updatedAt: DateTime.now(),
          );

      await adhaRepository.saveConversation(updatedConversationWithResponse);
      _currentlyActiveConversationId =
          updatedConversationWithResponse.id; // Set active ID

      emit(
        AdhaConversationActive(
          conversation: updatedConversationWithResponse,
          isProcessing: false,
          isVoiceActive: previousState?.isVoiceActive ?? false,
        ),
      );
    } on AdhaServiceException catch (e) {
      emit(AdhaError(e.message));
    } catch (e) {
      emit(
        AdhaError("Erreur lors de la création de la nouvelle conversation: $e"),
      );
    }
  }

  Future<void> _onLoadConversations(
    LoadConversations event,
    Emitter<AdhaState> emit,
  ) async {
    emit(const AdhaLoading());
    try {
      // Case 1: User explicitly wants the initial screen (_currentlyActiveConversationId is null).
      if (_currentlyActiveConversationId == null) {
        emit(const AdhaInitial());
        // Optional: In the background, ensure a default conversation exists if the repository is empty,
        // but don't make it active here as the user wants the initial screen.
        // This part is removed to strictly adhere to showing AdhaInitial if ID is null.
        // If no conversations exist at all, AdhaInitial is fine, user can start one.
        return;
      }

      // Case 2: A specific conversation is supposed to be active. Load it.
      // (_currentlyActiveConversationId is NOT null here)
      final AdhaConversation? conversation = await adhaRepository
          .getConversation(_currentlyActiveConversationId!);
      if (conversation != null) {
        emit(AdhaConversationActive(conversation: conversation));
      } else {
        // The active conversation ID was stored, but the conversation is gone from the repo.
        // This is an inconsistent state. Fallback: clear the active ID and go to AdhaInitial.
        _currentlyActiveConversationId = null; // Clear the bad ID
        emit(const AdhaInitial()); // Go to initial screen as a safe fallback
      }
    } catch (e) {
      _currentlyActiveConversationId =
          null; // Clear on error to prevent broken state
      emit(AdhaError('Erreur lors du chargement des conversations: $e'));
      // Optionally, after error, try to emit AdhaInitial so user is not stuck on error screen.
      // emit(const AdhaInitial());
    }
  }

  Future<void> _onLoadConversation(
    LoadConversation event,
    Emitter<AdhaState> emit,
  ) async {
    emit(const AdhaLoading());
    try {
      final conversation = await adhaRepository.getConversation(
        event.conversationId,
      );
      if (conversation != null) {
        _currentlyActiveConversationId = conversation.id; // Set active ID
        emit(AdhaConversationActive(conversation: conversation));
      } else {
        emit(const AdhaError('Conversation non trouvée'));
        add(const LoadConversations());
      }
    } catch (e) {
      emit(AdhaError('Erreur lors du chargement de la conversation: $e'));
    }
  }

  Future<void> _onDeleteConversation(
    DeleteConversation event,
    Emitter<AdhaState> emit,
  ) async {
    try {
      await adhaRepository.deleteConversation(event.conversationId);
      if (_currentlyActiveConversationId == event.conversationId) {
        _currentlyActiveConversationId =
            null; // Clear active ID if it was deleted
      }
      add(
        const LoadConversations(),
      ); // Reload, will go to AdhaInitial if active ID is now null
    } catch (e) {
      emit(AdhaError('Erreur lors de la suppression de la conversation: $e'));
    }
  }

  Future<void> _onStartVoiceRecognition(
    StartVoiceRecognition event,
    Emitter<AdhaState> emit,
  ) async {
    if (state is AdhaConversationActive) {
      final currentState = state as AdhaConversationActive;
      if (!currentState.isProcessing) {
        emit(currentState.copyWith(isVoiceActive: true));
        // _currentlyActiveConversationId remains what it was, voice is just an input method for current/new convo
      }
    } else {
      // This case implies starting voice recognition when not in an active conversation (e.g. from AdhaInitial)
      // A new conversation should be implicitly started or prepared.
      final newConversationId = _uuid.v4();
      final newConversation = AdhaConversation(
        id: newConversationId,
        title: 'Conversation vocale', // Temporary title
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
      // Don't save or set active ID yet, wait for actual speech input.
      // The AdhaConversationActive state here is to enable voice input UI.
      // The actual conversation will be formed by SendMessage after voice input.
      emit(
        AdhaConversationActive(
          conversation: newConversation,
          isVoiceActive: true,
          isProcessing: false,
        ),
      );
      // _currentlyActiveConversationId should ideally be set when the first message from voice is processed.
      // For now, if voice is started from AdhaInitial, _currentlyActiveConversationId is still null.
      // SendMessage will handle creating/activating the conversation.
    }
  }

  Future<void> _onStopVoiceRecognition(
    StopVoiceRecognition event,
    Emitter<AdhaState> emit,
  ) async {
    if (state is AdhaConversationActive) {
      final currentState = state as AdhaConversationActive;
      emit(currentState.copyWith(isVoiceActive: false));
    }
  }

  String _generateConversationTitle(String firstMessage) {
    String title = firstMessage.replaceAll('\n', ' ');
    if (title.length > 30) {
      title = '${title.substring(0, 27)}...';
    }
    return title.isEmpty ? "Nouvelle Conversation" : title;
  }

  AdhaMessageType _detectMessageType(String content) {
    if (content.contains('```')) {
      return AdhaMessageType.code;
    } else if (content.contains(r'\begin{equation}') ||
        content.contains(r'$$')) {
      return AdhaMessageType.latex;
    } else if (content.contains('<graph>') || content.contains('plt.show()')) {
      return AdhaMessageType.graph;
    }
    return AdhaMessageType.text;
  }

  // Gère la modification d\'un message par l\'utilisateur
  Future<void> _onEditMessage(
    EditMessage event,
    Emitter<AdhaState> emit,
  ) async {
    if (state is! AdhaConversationActive) {
      emit(
        const AdhaError(
          "Impossible de modifier un message : aucune conversation active.",
        ),
      );
      return;
    }

    final currentState = state as AdhaConversationActive;
    AdhaConversation currentConversation = currentState.conversation;

    int messageIndex = currentConversation.messages.indexWhere(
      (msg) => msg.id == event.messageId,
    );

    if (messageIndex == -1) {
      emit(
        AdhaError(
          "Impossible de modifier le message : ID non trouvé (${event.messageId}).",
        ),
      );
      return;
    }

    // Create the updated user message
    final editedUserMessage = currentConversation.messages[messageIndex]
        .copyWith(
          content: event.newContent,
          timestamp: DateTime.now(), // Update timestamp to reflect edit time
        );

    // Create a new list of messages, truncated up to the edited message
    final List<AdhaMessage> messagesUpToEdited = List.from(
      currentConversation.messages.take(messageIndex),
    );
    messagesUpToEdited.add(editedUserMessage); // Add the edited message

    final updatedConversationWithUserMsg = currentConversation.copyWith(
      messages: messagesUpToEdited,
      updatedAt: DateTime.now(),
      // Optionally, update the conversation title if the first message was edited
      title:
          messageIndex == 0
              ? _generateConversationTitle(event.newContent)
              : currentConversation.title,
    );

    emit(
      AdhaConversationActive(
        conversation: updatedConversationWithUserMsg,
        isProcessing: true, // Indicate processing as we will send to API
        isVoiceActive: currentState.isVoiceActive,
      ),
    );

    try {
      // Use the contextInfo from the event.
      // The EditMessage event requires contextInfo, so it won't be null.
      final AdhaContextInfo contextInfoForApi = event.contextInfo;

      final response = await adhaRepository.sendMessage(
        conversationId: currentConversation.id, // Use existing conversation ID
        message: event.newContent, // Send the new content
        contextInfo: contextInfoForApi,
        // Consider adding a parameter to sendMessage like `isEdit: true`
        // if the backend needs to specifically know this is a regeneration.
      );

      final adhaResponseMessage = AdhaMessage(
        id: _uuid.v4(),
        content: response.content,
        timestamp: DateTime.now(),
        sender: AdhaMessageSender.ai,
        type: _detectMessageType(response.content),
      );

      final finalMessages = List<AdhaMessage>.from(messagesUpToEdited)
        ..add(adhaResponseMessage);
      final finalConversation = updatedConversationWithUserMsg.copyWith(
        messages: finalMessages,
        updatedAt: DateTime.now(),
      );

      await adhaRepository.saveConversation(finalConversation);
      _currentlyActiveConversationId = finalConversation.id;

      emit(
        AdhaConversationActive(
          conversation: finalConversation,
          isProcessing: false,
          isVoiceActive: currentState.isVoiceActive,
        ),
      );
    } on AdhaServiceException catch (e) {
      emit(AdhaError(e.message));
      // Revert to the state before attempting to send the edited message
      emit(
        currentState.copyWith(
          isProcessing: false,
          conversation: updatedConversationWithUserMsg,
        ),
      );
    } catch (e) {
      emit(AdhaError("Erreur lors de la modification du message: $e"));
      // Revert to the state before attempting to send the edited message,
      // but keep user's edit locally in the conversation object for the UI.
      emit(
        currentState.copyWith(
          isProcessing: false,
          conversation: updatedConversationWithUserMsg,
        ),
      );
    }
  }

  /// Initialise les listeners pour le service audio
  void _initAudioListeners() {
    // Écouter les changements de connexion
    _audioConnectionSubscription = _audioStreamingService.connectionState
        .listen((connectionState) {
          add(
            AudioStateUpdate(
              connectionState: _mapServiceToStateConnectionState(
                connectionState,
              ),
              isRecording: false,
              isPlaying: false,
              audioLevel: 0.0,
            ),
          );
        });

    // Écouter les changements d'enregistrement
    _isRecordingSubscription = _audioStreamingService.isRecording.listen((
      isRecording,
    ) {
      // Utiliser add() au lieu d'emit() dans les listeners
      add(
        AudioStateUpdate(
          connectionState:
              state is AdhaConversationActive
                  ? (state as AdhaConversationActive).audioConnectionState
                  : AudioConnectionState.disconnected,
          isRecording: isRecording,
          isPlaying:
              state is AdhaConversationActive
                  ? (state as AdhaConversationActive).isAdhaPlaying
                  : false,
          audioLevel:
              state is AdhaConversationActive
                  ? (state as AdhaConversationActive).audioLevel
                  : 0.0,
        ),
      );
    });

    // Écouter les changements de lecture
    _isPlayingSubscription = _audioStreamingService.isPlaying.listen((
      isPlaying,
    ) {
      add(
        AudioStateUpdate(
          connectionState:
              state is AdhaConversationActive
                  ? (state as AdhaConversationActive).audioConnectionState
                  : AudioConnectionState.disconnected,
          isRecording:
              state is AdhaConversationActive
                  ? (state as AdhaConversationActive).isRecording
                  : false,
          isPlaying: isPlaying,
          audioLevel:
              state is AdhaConversationActive
                  ? (state as AdhaConversationActive).audioLevel
                  : 0.0,
        ),
      );
    });

    // Écouter les changements de niveau audio
    _audioLevelSubscription = _audioStreamingService.audioLevel.listen((
      audioLevel,
    ) {
      add(
        AudioStateUpdate(
          connectionState:
              state is AdhaConversationActive
                  ? (state as AdhaConversationActive).audioConnectionState
                  : AudioConnectionState.disconnected,
          isRecording:
              state is AdhaConversationActive
                  ? (state as AdhaConversationActive).isRecording
                  : false,
          isPlaying:
              state is AdhaConversationActive
                  ? (state as AdhaConversationActive).isAdhaPlaying
                  : false,
          audioLevel: audioLevel,
        ),
      );
    });
  }

  /// Démarre une session audio
  Future<void> _onStartAudioSession(
    StartAudioSession event,
    Emitter<AdhaState> emit,
  ) async {
    if (state is! AdhaConversationActive) {
      emit(
        const AdhaError(
          "Impossible de démarrer une session audio sans conversation active",
        ),
      );
      return;
    }

    final currentState = state as AdhaConversationActive;

    try {
      // Initialiser la session audio locale (permission micro + état).
      // Pas de WebSocket dédié : l'audio sera envoyé via REST
      // POST /commerce/adha/audio/stream et les chunks TTS de réponse
      // arrivent via le Socket.IO existant (AdhaStreamService).
      await _audioStreamingService.startAudioSession(
        conversationId: currentState.conversation.id,
      );

      // S'assurer que le Socket.IO de streaming est connecté pour
      // recevoir les chunks audio en retour.
      final connected = await _streamService.ensureConnected();
      if (!connected) {
        final authToken = await _getAuthToken();
        if (authToken.isNotEmpty) {
          await _streamService.connect(authToken);
        }
      }
      _streamService.subscribeToConversation(currentState.conversation.id);

      _isAudioSessionActive = true;

      emit(
        currentState.copyWith(
          isAudioStreamingActive: true,
          audioConnectionState: AudioConnectionState.connected,
        ),
      );

      // Envoyer un greeting pour déclencher immédiatement la voix Adha
      // (sinon l'utilisateur ouvre l'écran et ne sait pas quoi faire).
      final greetingRequestId = _uuid.v4();
      _currentStreamingRequestId = greetingRequestId;
      unawaited(
        _sendAudioSessionGreeting(currentState.conversation.id, greetingRequestId),
      );
    } catch (e) {
      emit(AdhaError("Erreur de démarrage de la session audio: $e"));
    }
  }

  /// Envoie un greeting (WAV silencieux + voice=nova) au démarrage de session
  /// pour déclencher une réponse vocale immédiate d'Adha. Sans ça, l'écran
  /// audio s'ouvre sans aucun feedback sonore tant que l'utilisateur ne
  /// parle pas.
  Future<void> _sendAudioSessionGreeting(
    String conversationId,
    String requestId,
  ) async {
    try {
      final contextInfo = await _buildContextInfo(
        AdhaInteractionType.followUp,
        sourceIdentifier: 'audio_duplex_greeting',
        conversationId: conversationId,
        interactionData: {
          'audio_prompt':
              '[Session audio démarrée] Salue brièvement l\'utilisateur et demande comment tu peux l\'aider.',
        },
      );
      final businessContextService = BusinessContextService();

      final silentWav = _createSilentWav();
      final silentBase64 = base64Encode(silentWav);

      await adhaRepository.sendAudioStreamingMessage(
        audioBase64: silentBase64,
        filename: 'greeting.wav',
        conversationId: conversationId,
        voice: 'nova',
        language: 'fr',
        contextInfo: contextInfo,
        companyId: businessContextService.companyId,
        userId: businessContextService.userId,
      );
      debugPrint('[AdhaBloc] ✅ Greeting audio envoyé (voice=nova)');
    } catch (e) {
      debugPrint('[AdhaBloc] ⚠️ Erreur greeting audio: $e');
    }
  }

  /// Crée un WAV silencieux de 0.5s — utilisé comme payload du greeting,
  /// le backend a juste besoin d'un audio valide pour déclencher le pipeline.
  Uint8List _createSilentWav() {
    const int sampleRate = 16000;
    const int durationMs = 500;
    final int samples = (sampleRate * durationMs ~/ 1000);
    final pcm = Uint8List(samples * 2); // 16-bit mono = 2 bytes/sample
    final dataSize = pcm.length;
    final fileSize = 36 + dataSize;
    final header = ByteData(44);
    header.setUint32(0, 0x52494646, Endian.big);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big);
    header.setUint32(12, 0x666d7420, Endian.big);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint32(36, 0x64617461, Endian.big);
    header.setUint32(40, dataSize, Endian.little);
    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, pcm);
    return result;
  }

  /// Termine une session audio
  Future<void> _onEndAudioSession(
    EndAudioSession event,
    Emitter<AdhaState> emit,
  ) async {
    if (state is! AdhaConversationActive) return;

    final currentState = state as AdhaConversationActive;

    try {
      _isAudioSessionActive = false;
      await _audioStreamingService.endSession();

      emit(
        currentState.copyWith(
          isAudioStreamingActive: false,
          audioConnectionState: AudioConnectionState.disconnected,
          isRecording: false,
          isAdhaPlaying: false,
          audioLevel: 0.0,
        ),
      );
    } catch (e) {
      emit(AdhaError("Erreur de fermeture de la session audio: $e"));
    }
  }

  /// Gère l'activation/désactivation de l'enregistrement
  Future<void> _onToggleRecording(
    ToggleRecording event,
    Emitter<AdhaState> emit,
  ) async {
    if (state is! AdhaConversationActive) return;

    final currentState = state as AdhaConversationActive;

    if (!currentState.isAudioStreamingActive) {
      emit(const AdhaError("Session audio non active"));
      return;
    }

    try {
      if (event.enabled) {
        // Barge-in : si Adha parle, interrompre la lecture pour écouter.
        if (currentState.isAdhaPlaying) {
          debugPrint('[AdhaBloc] ⛔ Barge-in: interruption Adha pour écouter');
          await _audioStreamingService.interrupt();
        }
        await _audioStreamingService.startRecording();
      } else {
        // Arrêter l'enregistrement et obtenir l'audio base64
        final audioBase64 =
            await _audioStreamingService.stopRecordingAndGetBase64();

        if (audioBase64 == null) {
          debugPrint('[AdhaBloc] Audio trop court ou vide, on relance l\'écoute');
          if (_isAudioSessionActive) {
            await Future.delayed(const Duration(milliseconds: 300));
            add(ToggleRecording(true));
          }
          return;
        }

        final conversationId = currentState.conversation.id;
        final contextInfo = await _buildContextInfo(
          AdhaInteractionType.followUp,
          sourceIdentifier: 'audio_duplex',
          conversationId: conversationId,
        );

        final requestMessageId = _uuid.v4();
        _currentStreamingRequestId = requestMessageId;

        final userMessage = AdhaMessage(
          id: requestMessageId,
          content: '🎙️ Message vocal',
          timestamp: DateTime.now(),
          sender: AdhaMessageSender.user,
        );
        final updatedMessages = List<AdhaMessage>.from(
          currentState.conversation.messages,
        )..add(userMessage);
        final updatedConversation = currentState.conversation.copyWith(
          messages: updatedMessages,
          updatedAt: DateTime.now(),
        );

        emit(
          currentState.copyWith(
            conversation: updatedConversation,
            isProcessing: true,
            isRecording: false,
          ),
        );

        _streamService.subscribeToConversation(conversationId);
        await Future.delayed(const Duration(milliseconds: 100));

        final businessContextService = BusinessContextService();
        if (!businessContextService.isInitialized ||
            businessContextService.companyId == null) {
          await authRepository.getUser(forceRemote: true);
        }
        final companyId = businessContextService.companyId;
        final userId = businessContextService.userId;

        if (companyId == null || companyId.isEmpty) {
          add(
            StreamError(
              conversationId: conversationId,
              errorMessage: 'Contexte business manquant.',
              requestMessageId: requestMessageId,
            ),
          );
          return;
        }

        // Envoyer l'audio via REST POST /adha/audio/stream avec voice=nova
        // pour activer le TTS côté backend (sinon aucun audio_chunk émis).
        try {
          await adhaRepository.sendAudioStreamingMessage(
            audioBase64: audioBase64,
            filename: 'recording.wav',
            conversationId: conversationId,
            voice: 'nova',
            language: 'fr',
            contextInfo: contextInfo,
            companyId: companyId,
            userId: userId,
          );
          debugPrint('[AdhaBloc] ✅ Audio envoyé (voice=nova) via REST');
        } on AdhaServiceException catch (e) {
          add(
            StreamError(
              conversationId: conversationId,
              errorMessage: e.message,
              requestMessageId: requestMessageId,
            ),
          );
        } catch (e) {
          add(
            StreamError(
              conversationId: conversationId,
              errorMessage: e.toString(),
              requestMessageId: requestMessageId,
            ),
          );
        }
      }
    } catch (e) {
      emit(AdhaError("Erreur de contrôle de l'enregistrement: $e"));
    }
  }

  /// Interrompt Adha pendant qu'il parle
  Future<void> _onInterruptAdha(
    InterruptAdha event,
    Emitter<AdhaState> emit,
  ) async {
    if (state is! AdhaConversationActive) return;

    final currentState = state as AdhaConversationActive;

    if (!currentState.isAudioStreamingActive) return;

    try {
      await _audioStreamingService.interrupt();

      // L'état sera mis à jour via les listeners
    } catch (e) {
      emit(AdhaError("Erreur d'interruption: $e"));
    }
  }

  /// Ajuste le volume audio
  Future<void> _onSetAudioVolume(
    SetAudioVolume event,
    Emitter<AdhaState> emit,
  ) async {
    try {
      await _audioStreamingService.setVolume(event.volume);
    } catch (e) {
      emit(AdhaError("Erreur de réglage du volume: $e"));
    }
  }

  /// Gère les mises à jour d'état audio
  Future<void> _onAudioStateUpdate(
    AudioStateUpdate event,
    Emitter<AdhaState> emit,
  ) async {
    if (state is! AdhaConversationActive) return;

    final currentState = state as AdhaConversationActive;

    emit(
      currentState.copyWith(
        audioConnectionState: event.connectionState,
        isRecording: event.isRecording,
        isAdhaPlaying: event.isPlaying,
        audioLevel: event.audioLevel,
      ),
    );
  }

  /// Récupère le token d'authentification JWT pour les requêtes authentifiées
  Future<String> _getAuthToken() async {
    try {
      // Option 1: Via ApiClient configuré (utilise Auth0Service ou fallback storage)
      final headers = await ApiClient().getHeaders(requiresAuth: true);
      final authHeader = headers[HttpHeaders.authorizationHeader];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring(7); // Retirer "Bearer "
        if (token.isNotEmpty) {
          debugPrint('[AdhaBloc] Token JWT récupéré via ApiClient');
          return token;
        }
      }

      // Option 2: Fallback direct vers secure storage (pour Desktop)
      const storage = FlutterSecureStorage();
      final token =
          await storage.read(key: 'desktop_access_token') ??
          await storage.read(key: 'access_token') ??
          await storage.read(key: 'auth_token');
      if (token != null && token.isNotEmpty) {
        debugPrint('[AdhaBloc] Token JWT récupéré via FlutterSecureStorage');
        return token;
      }

      debugPrint('[AdhaBloc] ⚠️ Aucun token JWT trouvé');
      return '';
    } catch (e) {
      debugPrint('[AdhaBloc] Erreur récupération token: $e');
      return '';
    }
  }

  // ============================================================================
  // MÉTHODES DE STREAMING (Janvier 2026)
  // ============================================================================

  /// Initialise les listeners pour le service de streaming
  void _initStreamListeners() {
    // Écouter les chunks de streaming
    _streamChunkSubscription = _streamService.chunkStream.listen(
      _handleStreamChunk,
      onError: (error) {
        add(
          StreamError(
            conversationId: _currentlyActiveConversationId ?? '',
            errorMessage: error.toString(),
            requestMessageId: _currentStreamingRequestId,
          ),
        );
      },
    );

    // Écouter les changements de connexion
    _streamConnectionSubscription = _streamService.connectionState.listen((
      connectionState,
    ) {
      // Mapper l'état de connexion du service vers l'état du bloc
      // Note: Les changements d'état de connexion sont gérés via les événements
      // ConnectToStreamService et DisconnectFromStreamService
      // Ce listener est utilisé pour le logging/debugging
      debugPrint('[AdhaBloc] Stream connection state: ${connectionState.name}');
    });

    // Écouter les chunks audio TTS (v3.0) — chaque phrase synthétisée par
    // le backend est jouée en séquence via la queue FIFO du service audio.
    // Si l'écoute échoue (audio service indispo), on dégrade silencieusement
    // — le chat texte continue de fonctionner normalement.
    _ttsAudioChunkSubscription = _streamService.audioChunkStream.listen(
      (audioChunk) {
        _audioStreamingService.playBase64Audio(
          audioChunk.audioBase64,
          audioChunk.format,
        );
        debugPrint(
          '[AdhaBloc] 🔊 Audio TTS en lecture: chunkId=${audioChunk.chunkId}, '
          'voice=${audioChunk.voice}',
        );
      },
      onError: (error) {
        debugPrint('[AdhaBloc] Erreur audio chunk: $error');
      },
    );
  }

  /// Ajoute un chunk au buffer de batching et planifie/déclenche un flush.
  ///
  /// Règle : flush dès que le buffer dépasse [_chunkBatchMaxChars] (rafale
  /// dense), sinon flush au plus tard après [_chunkBatchWindowMs] (latence
  /// max perceptible). Émet UN SEUL StreamChunkReceived par fenêtre au lieu
  /// de potentiellement 50/seconde, ce qui divise les rebuilds par un ordre
  /// de grandeur sans changer le contenu final.
  void _bufferChunkForBatch(AdhaStreamChunkEvent chunk) {
    _chunkBatchBuffer.write(chunk.content);
    _chunkBatchLatestChunkId = chunk.chunkId;
    _chunkBatchConversationId = chunk.conversationId;
    _chunkBatchRequestMessageId = chunk.requestMessageId;

    if (_chunkBatchBuffer.length >= _chunkBatchMaxChars) {
      _chunkBatchTimer?.cancel();
      _chunkBatchTimer = null;
      _flushChunkBatch();
      return;
    }

    _chunkBatchTimer ??= Timer(
      const Duration(milliseconds: _chunkBatchWindowMs),
      _flushChunkBatch,
    );
  }

  /// Émet le buffer accumulé sous forme d'un seul StreamChunkReceived.
  /// Sans-op si le buffer est vide.
  void _flushChunkBatch() {
    _chunkBatchTimer?.cancel();
    _chunkBatchTimer = null;
    if (_chunkBatchBuffer.isEmpty) return;

    final combined = _chunkBatchBuffer.toString();
    _chunkBatchBuffer.clear();

    add(
      StreamChunkReceived(
        conversationId: _chunkBatchConversationId,
        content: combined,
        chunkId: _chunkBatchLatestChunkId,
        requestMessageId: _chunkBatchRequestMessageId,
      ),
    );
  }

  /// Gère les chunks de streaming reçus
  void _handleStreamChunk(AdhaStreamChunkEvent chunk) {
    switch (chunk.type) {
      case AdhaStreamType.chunk:
        // Fragment de texte normal — bufferisé pour grouper les rebuilds.
        // L'accumulation finale (côté state) est faite dans _onStreamChunkReceived
        // mais on regroupe d'abord les micro-chunks pour éviter une rafale
        // d'événements/rebuilds qui dégradent la fluidité.
        _bufferChunkForBatch(chunk);
        break;

      case AdhaStreamType.end:
        // Flush IMMÉDIAT du buffer batching pour ne perdre aucun chunk
        // resté en attente du prochain tick de fenêtre (60ms).
        _flushChunkBatch();
        // Fin du streaming - utiliser le contenu accumulé
        // IMPORTANT: Attendre un court instant pour que les chunks en queue soient traités
        // avant de finaliser le streaming. Les événements arrivent de manière asynchrone
        // et le 'end' peut arriver avant que tous les 'chunk' events ne soient traités.
        Future.delayed(const Duration(milliseconds: 100), () {
          final accumulatedContent = _accumulatedStreamContent.toString();
          debugPrint(
            '[AdhaBloc] 📝 StreamEnd traité - contenu accumulé: ${accumulatedContent.length} caractères',
          );
          add(
            StreamCompleted(
              conversationId: chunk.conversationId,
              fullContent:
                  accumulatedContent.isNotEmpty
                      ? accumulatedContent
                      : chunk.content,
              requestMessageId: chunk.requestMessageId,
              totalChunks: chunk.totalChunks ?? chunk.chunkId,
              processingDetails: chunk.processingDetails,
            ),
          );
        });
        break;

      case AdhaStreamType.error:
        // Flush buffer pour ne pas perdre un éventuel contenu pré-erreur.
        _flushChunkBatch();
        // Erreur pendant le streaming
        // Extraire les métadonnées d'abonnement si présentes
        add(
          StreamError(
            conversationId: chunk.conversationId,
            errorMessage: chunk.content,
            requestMessageId: chunk.requestMessageId,
            errorType: chunk.metadata?.errorType,
            subscriptionRenewalUrl: chunk.metadata?.subscriptionRenewalUrl,
            requiresAction: chunk.metadata?.requiresAction,
            upgradeRequired: chunk.metadata?.upgradeRequired,
            feature: chunk.metadata?.feature,
            currentUsage: chunk.metadata?.currentUsage,
            limit: chunk.metadata?.limit,
            gracePeriodDaysRemaining: chunk.metadata?.gracePeriodDaysRemaining,
          ),
        );
        break;

      case AdhaStreamType.toolCall:
      case AdhaStreamType.toolResult:
        // Appels de fonctions IA - optionnel: afficher un indicateur
        // Pour l'instant, on les ignore silencieusement
        break;

      case AdhaStreamType.cancelled:
        // Stream annulé par l'utilisateur ou le serveur (v2.4.0)
        add(CancelStreaming(conversationId: chunk.conversationId));
        break;

      case AdhaStreamType.heartbeat:
        // Heartbeat - signal de connexion active (v2.4.0)
        // Ne nécessite aucune action, juste pour maintenir la connexion
        debugPrint('[AdhaBloc] 💓 Heartbeat reçu');
        break;
    }
  }

  /// Connecte au service de streaming
  ///
  /// Selon la documentation ADHA (Janvier 2026):
  /// - Connexion via Socket.IO à l'API Gateway (/commerce/chat)
  /// - Authentification via token JWT dans l'objet auth
  Future<void> _onConnectToStreamService(
    ConnectToStreamService event,
    Emitter<AdhaState> emit,
  ) async {
    debugPrint('[AdhaBloc] 🔌 Tentative de connexion au streaming...');
    try {
      final businessContextService = BusinessContextService();
      debugPrint(
        '[AdhaBloc] BusinessContext - isInitialized: ${businessContextService.isInitialized}, companyId: ${businessContextService.companyId}',
      );

      if (!businessContextService.isInitialized ||
          businessContextService.companyId == null) {
        debugPrint(
          '[AdhaBloc] BusinessContext non initialisé, tentative getUser...',
        );
        await authRepository.getUser(forceRemote: true);
        debugPrint(
          '[AdhaBloc] Après getUser - isInitialized: ${businessContextService.isInitialized}, companyId: ${businessContextService.companyId}',
        );
      }

      if (!businessContextService.isInitialized ||
          businessContextService.companyId == null) {
        debugPrint(
          '[AdhaBloc] ❌ BusinessContext toujours indisponible après getUser',
        );
        emit(
          const AdhaStreamConnected(
            connectionState: StreamConnectionState.error,
            errorMessage:
                'Contexte business indisponible. Veuillez réessayer après la récupération du profil (/users/me).',
          ),
        );
        return;
      }

      // Récupérer le token d'authentification
      final authToken = event.authToken ?? await _getAuthToken();
      debugPrint(
        '[AdhaBloc] Token JWT récupéré: ${authToken.isNotEmpty ? "✅ (${authToken.length} chars)" : "❌ vide"}',
      );

      if (authToken.isEmpty) {
        debugPrint('[AdhaBloc] ❌ Token vide, abandon connexion streaming');
        emit(
          const AdhaStreamConnected(
            connectionState: StreamConnectionState.error,
            errorMessage: 'Token d\'authentification manquant',
          ),
        );
        return;
      }

      // Connecter au service de streaming avec le token JWT
      debugPrint('[AdhaBloc] 🚀 Connexion à AdhaStreamService...');
      await _streamService.connect(authToken);
      debugPrint('[AdhaBloc] ✅ Connexion streaming initiée');

      emit(
        const AdhaStreamConnected(
          connectionState: StreamConnectionState.connected,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[AdhaBloc] ❌ Erreur connexion streaming: $e');
      debugPrint('[AdhaBloc] StackTrace: $stackTrace');
      emit(
        AdhaStreamConnected(
          connectionState: StreamConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Déconnecte du service de streaming
  Future<void> _onDisconnectFromStreamService(
    DisconnectFromStreamService event,
    Emitter<AdhaState> emit,
  ) async {
    await _streamService.disconnect();

    emit(
      const AdhaStreamConnected(
        connectionState: StreamConnectionState.disconnected,
      ),
    );
  }

  /// Envoie un message avec streaming
  Future<void> _onSendStreamingMessage(
    SendStreamingMessage event,
    Emitter<AdhaState> emit,
  ) async {
    AdhaConversation currentConversation;
    AdhaContextInfo contextInfoForApi;
    bool isNewConversation = false;
    String? conversationIdForApi;

    // Réinitialiser le buffer de streaming
    _accumulatedStreamContent.clear();

    // Récupérer companyId et userId pour les envoyer au backend ADHA
    // Le companyId n'est PAS dans le JWT, donc on doit l'envoyer explicitement
    // Le userId doit être l'UUID de la base de données, pas l'Auth0 ID
    final businessContextService = BusinessContextService();
    final companyId = businessContextService.companyId;
    final userId = businessContextService.userId; // UUID de la DB, pas Auth0 ID

    debugPrint(
      '[AdhaBloc] companyId: $companyId, userId: $userId pour requête ADHA',
    );

    // Déterminer ou créer la conversation
    // NOUVEAU (Janvier 2026): Le frontend génère toujours le conversationId
    // pour permettre la souscription WebSocket AVANT l'envoi du message.
    // Le backend DOIT accepter ce conversationId fourni par le client.
    if (state is AdhaConversationActive) {
      final currentState = state as AdhaConversationActive;
      currentConversation = currentState.conversation;
      conversationIdForApi = currentConversation.id; // Conversation existante
      contextInfoForApi = await _buildContextInfo(
        event.contextInfo?.interactionContext.interactionType ??
            AdhaInteractionType.followUp,
        sourceIdentifier:
            event.contextInfo?.interactionContext.sourceIdentifier,
        interactionData: event.contextInfo?.interactionContext.interactionData,
        conversationId: currentConversation.id,
      );
    } else if (state is AdhaStreaming) {
      // Déjà en streaming, ignorer
      return;
    } else {
      if (event.contextInfo == null) {
        emit(
          const AdhaError(
            "ContextInfo est requis pour démarrer une nouvelle conversation.",
          ),
        );
        return;
      }
      isNewConversation = true;
      // NOUVEAU: Le frontend génère le conversationId (UUID)
      // et l'envoie au backend pour permettre le streaming dès le premier message
      final clientGeneratedConversationId = _uuid.v4();
      conversationIdForApi = clientGeneratedConversationId; // Envoyé au backend
      debugPrint(
        '[AdhaBloc] 🆕 Nouvelle conversation - ID généré côté client: $clientGeneratedConversationId',
      );
      currentConversation = AdhaConversation(
        id: clientGeneratedConversationId, // ID généré côté client
        title: _generateConversationTitle(event.message),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
      contextInfoForApi = await _buildContextInfo(
        event.contextInfo!.interactionContext.interactionType,
        sourceIdentifier:
            event.contextInfo!.interactionContext.sourceIdentifier,
        interactionData: event.contextInfo!.interactionContext.interactionData,
        conversationId:
            clientGeneratedConversationId, // Inclure l'ID dans le contexte
      );
    }

    // Créer le message utilisateur
    final requestMessageId = _uuid.v4();
    _currentStreamingRequestId = requestMessageId;

    final userMessage = AdhaMessage(
      id: requestMessageId,
      content: event.message,
      timestamp: DateTime.now(),
      sender: AdhaMessageSender.user,
    );

    final updatedMessages = List<AdhaMessage>.from(currentConversation.messages)
      ..add(userMessage);
    final updatedConversation = currentConversation.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    // Émettre l'état de streaming
    // NOUVEAU (Janvier 2026): L'ID est généré côté client, donc isPendingConversationId=false
    // car on a déjà l'ID final (pas besoin d'attendre le backend)
    emit(
      AdhaStreaming(
        conversation: updatedConversation,
        partialContent: '',
        currentChunkId: 0,
        requestMessageId: requestMessageId,
        conversationId: currentConversation.id,
        isStreaming: true,
        isPendingConversationId: false, // ID généré côté client, pas en attente
      ),
    );

    // S'assurer que la connexion WebSocket est active avant d'envoyer
    // Si la connexion a été perdue (timeout, app en arrière-plan, etc.), reconnecter
    // On passe le token JWT pour permettre la reconnexion même si connect() n'a jamais été appelé
    final authToken = await _getAuthToken();
    final isWebSocketConnected = await _streamService.ensureConnected(
      authToken: authToken,
    );
    debugPrint('[AdhaBloc] WebSocket connecté: $isWebSocketConnected');

    // Vérifier la connexion au service de streaming
    if (!isWebSocketConnected) {
      debugPrint(
        '[AdhaBloc] WebSocket non connecté - utilisation du mode synchrone',
      );
      // Fallback vers l'envoi classique si non connecté
      try {
        final response = await adhaRepository.sendMessage(
          conversationId:
              conversationIdForApi, // null pour nouvelle conversation
          message: event.message,
          contextInfo: contextInfoForApi,
          companyId: companyId,
          userId: userId,
        );

        // Si c'était une nouvelle conversation, mettre à jour l'ID avec celui du backend
        String finalConversationId = currentConversation.id;
        if (isNewConversation && response.conversationId.isNotEmpty) {
          finalConversationId = response.conversationId;
          currentConversation = currentConversation.copyWith(
            id: response.conversationId,
          );
          // Mettre à jour la conversation dans l'état avec l'ID confirmé du backend
          final updatedWithBackendId = updatedConversation.copyWith(
            id: response.conversationId,
          );
          emit(
            AdhaStreaming(
              conversation: updatedWithBackendId,
              partialContent: '',
              currentChunkId: 0,
              requestMessageId: requestMessageId,
              conversationId: response.conversationId,
              isStreaming: true,
              isPendingConversationId: false, // ID confirmé par le backend
            ),
          );
        }

        // Simuler la fin du streaming
        add(
          StreamCompleted(
            conversationId: finalConversationId,
            fullContent: response.content,
            requestMessageId: requestMessageId,
            totalChunks: 1,
          ),
        );
      } on AdhaServiceException catch (e) {
        add(
          StreamError(
            conversationId: currentConversation.id,
            errorMessage: e.message,
            requestMessageId: requestMessageId,
          ),
        );
      } catch (e) {
        add(
          StreamError(
            conversationId: currentConversation.id,
            errorMessage: e.toString(),
            requestMessageId: requestMessageId,
          ),
        );
      }
      return;
    }

    // NOUVEAU (Janvier 2026): Le frontend génère le conversationId
    // On peut maintenant s'abonner à la room WebSocket AVANT d'envoyer le message
    // pour TOUTES les conversations (nouvelles ou existantes).
    // Cela permet le vrai streaming temps réel dès le premier message.

    // S'abonner AVANT d'envoyer le message (nouvelle ou existante)
    debugPrint(
      '[AdhaBloc] 📝 Souscription WebSocket à ${currentConversation.id} AVANT envoi du message',
    );
    _streamService.subscribeToConversation(currentConversation.id);

    // Petit délai pour s'assurer que la souscription est bien enregistrée côté serveur
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // NOUVEAU (Janvier 2026): Streaming activé pour TOUTES les conversations
      // Le frontend envoie le conversationId généré côté client
      // Le backend utilise cet ID au lieu d'en générer un nouveau

      if (isNewConversation && event.streaming && _streamService.isConnected) {
        // Nouvelle conversation avec streaming: envoyer via /stream avec l'ID généré
        debugPrint(
          '[AdhaBloc] 🚀 Nouvelle conversation - STREAMING avec ID client: ${currentConversation.id}',
        );

        final streamResponse = await adhaRepository.sendStreamingMessage(
          conversationId: conversationIdForApi, // ID généré côté client!
          message: event.message,
          contextInfo: contextInfoForApi,
          attachments: event.attachments,
          companyId: companyId,
          userId: userId,
        );

        // Les chunks arriveront via Socket.IO (client déjà abonné)
        debugPrint(
          '[AdhaBloc] ✅ Streaming initié pour nouvelle conv - requestMessageId: ${streamResponse.requestMessageId}',
        );
        // Ne pas faire de add() ici, les chunks arrivent via WebSocket
        return;
      } else if (isNewConversation) {
        // Fallback: nouvelle conversation SANS streaming (WebSocket non connecté)
        debugPrint(
          '[AdhaBloc] ⚠️ Nouvelle conversation - WebSocket non disponible, fallback synchrone',
        );

        // Mode synchrone pour nouvelle conversation (fallback)
        final response = await adhaRepository.sendMessage(
          conversationId: conversationIdForApi, // ID généré côté client!
          message: event.message,
          contextInfo: contextInfoForApi,
          companyId: companyId,
          userId: userId,
        );

        // L'ID de conversation reste celui généré par le client
        // Le backend DOIT utiliser cet ID, mais on vérifie quand même la réponse
        final responseConversationId = response.conversationId;

        // Si le backend retourne un ID différent (ancien comportement), logger un warning
        if (responseConversationId.isNotEmpty &&
            responseConversationId != conversationIdForApi) {
          debugPrint(
            '[AdhaBloc] ⚠️ Backend a retourné un ID différent: $responseConversationId vs $conversationIdForApi',
          );
          debugPrint(
            '[AdhaBloc] ⚠️ Le backend doit être mis à jour pour accepter l\'ID du client',
          );
          // Utiliser l'ID du backend si différent (compatibilité ancienne version)
          currentConversation = currentConversation.copyWith(
            id: responseConversationId,
          );
          final updatedWithBackendId = updatedConversation.copyWith(
            id: responseConversationId,
          );
          // S'abonner avec le nouvel ID si différent
          _streamService.subscribeToConversation(responseConversationId);

          // CORRECTION: Le backend peut avoir streamé la réponse via Kafka/WebSocket
          // et sauvegardé en DB AVANT que la réponse HTTP n'arrive.
          // Si response.content est vide ou contient un message d'erreur timeout,
          // récupérer l'historique de la conversation depuis la DB.
          String aiResponseContent = response.content;

          debugPrint(
            '[AdhaBloc] Réponse HTTP reçue: "${aiResponseContent.substring(0, aiResponseContent.length > 100 ? 100 : aiResponseContent.length)}..."',
          );

          // Détecter si c'est un message de timeout
          final isTimeout =
              aiResponseContent.isEmpty ||
              aiResponseContent.contains('délai raisonnable') ||
              aiResponseContent.contains('delai raisonnable') || // Sans accent
              aiResponseContent.contains('timeout') ||
              aiResponseContent.contains('réessayer plus tard') ||
              aiResponseContent.contains(
                'reessayer plus tard',
              ) || // Sans accent
              aiResponseContent.contains('pas pu traiter votre demande');

          debugPrint('[AdhaBloc] isTimeout=$isTimeout');

          if (isTimeout) {
            debugPrint(
              '[AdhaBloc] Réponse HTTP vide/timeout - récupération depuis l\'historique DB',
            );

            // Attendre un court instant pour que la DB soit à jour
            await Future.delayed(const Duration(milliseconds: 500));

            // Récupérer l'historique de la conversation
            try {
              debugPrint(
                '[AdhaBloc] Récupération historique pour $responseConversationId...',
              );
              final history = await adhaRepository
                  .fetchConversationHistoryFromServer(responseConversationId);

              debugPrint(
                '[AdhaBloc] Historique récupéré: ${history.length} messages',
              );

              // Log tous les messages pour debug
              for (int i = 0; i < history.length; i++) {
                final m = history[i];
                debugPrint(
                  '[AdhaBloc] Message[$i]: sender=${m.sender}, content="${m.content.substring(0, m.content.length > 50 ? 50 : m.content.length)}..."',
                );
              }

              // Trouver les messages AI qui ne sont PAS des messages de timeout
              // Le backend peut avoir inséré un message timeout APRÈS le vrai message AI
              final validAiMessages =
                  history
                      .where(
                        (m) =>
                            m.sender == AdhaMessageSender.ai &&
                            !m.content.contains('délai raisonnable') &&
                            !m.content.contains('delai raisonnable') &&
                            !m.content.contains('réessayer plus tard') &&
                            !m.content.contains('reessayer plus tard') &&
                            !m.content.contains('pas pu traiter votre demande'),
                      )
                      .toList();

              debugPrint(
                '[AdhaBloc] Messages AI valides trouvés: ${validAiMessages.length}',
              );

              if (validAiMessages.isNotEmpty) {
                // Prendre le dernier message AI valide (le plus récent qui n'est pas un timeout)
                final validAiMessage = validAiMessages.last;
                aiResponseContent = validAiMessage.content;
                debugPrint(
                  '[AdhaBloc] ✅ Réponse AI récupérée depuis DB: ${aiResponseContent.length} caractères',
                );
              } else {
                debugPrint(
                  '[AdhaBloc] ⚠️ Aucun message AI valide trouvé dans l\'historique',
                );
              }
            } catch (e) {
              debugPrint('[AdhaBloc] Erreur récupération historique: $e');
            }
          }

          emit(
            AdhaStreaming(
              conversation: updatedWithBackendId,
              partialContent: aiResponseContent,
              currentChunkId: 1,
              requestMessageId: requestMessageId,
              conversationId: responseConversationId,
              isStreaming: true,
              isPendingConversationId: false,
            ),
          );

          // Compléter le streaming avec le contenu récupéré
          add(
            StreamCompleted(
              conversationId: responseConversationId,
              fullContent: aiResponseContent,
              requestMessageId: requestMessageId,
              totalChunks: 1,
            ),
          );
        } else {
          // Backend a utilisé l'ID fourni par le client - comportement attendu
          debugPrint(
            '[AdhaBloc] ✅ Backend a utilisé l\'ID client: $conversationIdForApi',
          );

          // Compléter le streaming avec la réponse directe
          add(
            StreamCompleted(
              conversationId: currentConversation.id,
              fullContent: response.content,
              requestMessageId: requestMessageId,
              totalChunks: 1,
            ),
          );
        }
      } else if (event.streaming && _streamService.isConnected) {
        // Conversation existante + streaming activé + connecté: utiliser le streaming
        debugPrint(
          '[AdhaBloc] Conversation existante - utilisation du mode streaming',
        );

        final streamResponse = await adhaRepository.sendStreamingMessage(
          conversationId: conversationIdForApi,
          message: event.message,
          contextInfo: contextInfoForApi,
          attachments: event.attachments,
          companyId: companyId,
          userId: userId,
        );

        // Les chunks arriveront via Socket.IO (client déjà abonné)
        debugPrint(
          '[AdhaBloc] Streaming initié - requestMessageId: ${streamResponse.requestMessageId}',
        );
      } else {
        // Fallback: mode synchrone
        debugPrint('[AdhaBloc] Fallback vers mode synchrone');

        final response = await adhaRepository.sendMessage(
          conversationId: conversationIdForApi,
          message: event.message,
          contextInfo: contextInfoForApi,
          companyId: companyId,
          userId: userId,
        );

        add(
          StreamCompleted(
            conversationId: currentConversation.id,
            fullContent: response.content,
            requestMessageId: requestMessageId,
            totalChunks: 1,
          ),
        );
      }
    } on AdhaServiceException catch (e) {
      add(
        StreamError(
          conversationId: currentConversation.id,
          errorMessage: e.message,
          requestMessageId: requestMessageId,
        ),
      );
    } catch (e) {
      add(
        StreamError(
          conversationId: currentConversation.id,
          errorMessage: e.toString(),
          requestMessageId: requestMessageId,
        ),
      );
    }
  }

  /// Gère la réception d'un chunk de streaming
  Future<void> _onStreamChunkReceived(
    StreamChunkReceived event,
    Emitter<AdhaState> emit,
  ) async {
    if (state is! AdhaStreaming) {
      debugPrint(
        '[AdhaBloc] ⚠️ Chunk reçu mais état n\'est pas AdhaStreaming: ${state.runtimeType}',
      );
      return;
    }

    final currentState = state as AdhaStreaming;

    // CORRECTION (Janvier 2026): Utiliser le conversationId pour filtrer les chunks
    // au lieu du requestMessageId qui n'est pas cohérent entre client et backend.
    // Le conversationId est maintenant généré côté client et utilisé des deux côtés.
    if (currentState.conversationId != event.conversationId) {
      debugPrint(
        '[AdhaBloc] ⚠️ Chunk ignoré: conversationId mismatch (state: ${currentState.conversationId}, event: ${event.conversationId})',
      );
      return;
    }

    debugPrint(
      '[AdhaBloc] ✅ Chunk #${event.chunkId} accepté pour ${event.conversationId}: "${event.content}"',
    );

    // Accumuler le contenu
    _accumulatedStreamContent.write(event.content);

    // Émettre le nouvel état avec le contenu accumulé
    emit(currentState.appendContent(event.content, event.chunkId));
  }

  /// Gère la fin du streaming
  Future<void> _onStreamCompleted(
    StreamCompleted event,
    Emitter<AdhaState> emit,
  ) async {
    AdhaConversation conversation;

    if (state is AdhaStreaming) {
      final streamingState = state as AdhaStreaming;
      conversation = streamingState.conversation;
    } else if (state is AdhaConversationActive) {
      conversation = (state as AdhaConversationActive).conversation;
    } else {
      // État inattendu, récupérer la conversation depuis le repository
      final conv = await adhaRepository.getConversation(event.conversationId);
      if (conv == null) {
        emit(AdhaError("Conversation non trouvée: ${event.conversationId}"));
        return;
      }
      conversation = conv;
    }

    // Créer le message de réponse d'ADHA
    final adhaMessage = AdhaMessage(
      id: _uuid.v4(),
      content: event.fullContent,
      timestamp: DateTime.now(),
      sender: AdhaMessageSender.ai,
      type: _detectMessageType(event.fullContent),
    );

    final finalMessages = List<AdhaMessage>.from(conversation.messages)
      ..add(adhaMessage);
    final finalConversation = conversation.copyWith(
      messages: finalMessages,
      updatedAt: DateTime.now(),
    );

    // Sauvegarder la conversation
    await adhaRepository.saveConversation(finalConversation);
    _currentlyActiveConversationId = finalConversation.id;

    // Réinitialiser le buffer et l'ID de streaming
    _accumulatedStreamContent.clear();
    _currentStreamingRequestId = null;

    emit(
      AdhaConversationActive(
        conversation: finalConversation,
        isProcessing: false,
      ),
    );
  }

  /// Gère les erreurs de streaming
  Future<void> _onStreamError(
    StreamError event,
    Emitter<AdhaState> emit,
  ) async {
    _accumulatedStreamContent.clear();
    _currentStreamingRequestId = null;

    // Vérifier si c'est une erreur liée à l'abonnement
    if (event.isSubscriptionRelated) {
      final errorType = SubscriptionErrorType.fromBackendType(event.errorType);
      if (errorType != null) {
        emit(
          AdhaSubscriptionError(
            errorType: errorType,
            message: event.errorMessage,
            renewalUrl: event.subscriptionRenewalUrl,
            upgradeRequired: event.upgradeRequired ?? false,
            feature: event.feature,
            currentUsage: event.currentUsage,
            limit: event.limit,
            gracePeriodDaysRemaining: event.gracePeriodDaysRemaining,
          ),
        );
        return;
      }
    }

    emit(AdhaError("Erreur de streaming: ${event.errorMessage}"));

    // Restaurer l'état de conversation si disponible
    if (event.conversationId.isNotEmpty) {
      final conversation = await adhaRepository.getConversation(
        event.conversationId,
      );
      if (conversation != null) {
        emit(
          AdhaConversationActive(
            conversation: conversation,
            isProcessing: false,
          ),
        );
      }
    }
  }

  /// Annule le streaming en cours
  Future<void> _onCancelStreaming(
    CancelStreaming event,
    Emitter<AdhaState> emit,
  ) async {
    _accumulatedStreamContent.clear();
    _currentStreamingRequestId = null;

    if (state is AdhaStreaming) {
      final streamingState = state as AdhaStreaming;
      emit(
        AdhaConversationActive(
          conversation: streamingState.conversation,
          isProcessing: false,
        ),
      );
    }
  }

  /// Réinitialise l'état pour démarrer une nouvelle conversation
  Future<void> _onClearCurrentConversation(
    ClearCurrentConversation event,
    Emitter<AdhaState> emit,
  ) async {
    _currentlyActiveConversationId = null;
    _accumulatedStreamContent.clear();
    _currentStreamingRequestId = null;

    // Persister le fait qu'il n'y a plus de conversation active
    await adhaRepository.saveActiveConversationId(null);

    emit(const AdhaInitial());
  }

  /// Initialise le repository pour un utilisateur spécifique
  /// Appelé après la connexion pour isoler les conversations par utilisateur
  Future<void> _onInitializeForUser(
    InitializeForUser event,
    Emitter<AdhaState> emit,
  ) async {
    try {
      debugPrint('[AdhaBloc] Initialisation pour utilisateur: ${event.userId}');

      // Vérifier si on est déjà initialisé pour cet utilisateur
      final alreadyInitialized = adhaRepository.isInitializedForUser(
        event.userId,
      );

      if (alreadyInitialized) {
        debugPrint(
          '[AdhaBloc] ✅ Déjà initialisé pour cet utilisateur, restauration de l\'état',
        );

        // Restaurer la conversation active depuis le cache
        if (_currentlyActiveConversationId == null) {
          final savedActiveId = adhaRepository.getActiveConversationId();
          if (savedActiveId != null) {
            final conversation = await adhaRepository.getConversation(
              savedActiveId,
            );
            if (conversation != null) {
              _currentlyActiveConversationId = savedActiveId;
              emit(AdhaConversationActive(conversation: conversation));
              debugPrint('[AdhaBloc] ✅ Conversation restaurée: $savedActiveId');
              return;
            }
          }
        } else {
          // Une conversation est déjà active en mémoire, ne pas la réinitialiser
          debugPrint('[AdhaBloc] ✅ Conversation déjà active, état conservé');
          return;
        }

        emit(const AdhaInitial());
        return;
      }

      // Nouveau utilisateur ou première initialisation
      _accumulatedStreamContent.clear();
      _currentStreamingRequestId = null;

      final userChanged = await adhaRepository.init(userId: event.userId);

      if (userChanged) {
        _currentlyActiveConversationId = null;
        emit(const AdhaInitial());
      } else {
        // Même utilisateur, restaurer la conversation active si elle existe
        final savedActiveId = adhaRepository.getActiveConversationId();
        if (savedActiveId != null) {
          final conversation = await adhaRepository.getConversation(
            savedActiveId,
          );
          if (conversation != null) {
            _currentlyActiveConversationId = savedActiveId;
            emit(AdhaConversationActive(conversation: conversation));
            return;
          }
        }
        emit(const AdhaInitial());
      }
    } catch (e) {
      debugPrint('[AdhaBloc] ❌ Erreur lors de l\'initialisation: $e');
      emit(AdhaError('Erreur d\'initialisation: $e'));
    }
  }

  @override
  Future<void> close() async {
    // Nettoyer les subscriptions audio
    await _audioConnectionSubscription?.cancel();
    await _audioLevelSubscription?.cancel();
    await _isRecordingSubscription?.cancel();
    await _isPlayingSubscription?.cancel();

    // Nettoyer les subscriptions de streaming
    await _streamChunkSubscription?.cancel();
    await _streamConnectionSubscription?.cancel();
    await _ttsAudioChunkSubscription?.cancel();

    // Annuler le timer de batching de chunks (Phase 2D)
    _chunkBatchTimer?.cancel();
    _chunkBatchTimer = null;

    // Nettoyer les services
    _audioStreamingService.dispose();
    _streamService.dispose();

    // Fermer le repository
    await adhaRepository.close();

    return super.close();
  }
}
