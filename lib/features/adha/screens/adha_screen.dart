import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import '../bloc/adha_bloc.dart';
import '../bloc/adha_event.dart';
import '../bloc/adha_state.dart';
import '../models/adha_message.dart'; // Added import for AdhaMessage
import '../models/adha_attachment.dart'; // Added for attachments
import '../widgets/adha_error_widget.dart'; // Widget d'erreur user-friendly
import 'chat_message_widget.dart';
import 'streaming_message_widget.dart'; // Import du widget de streaming
import '../models/adha_context_info.dart'; // Added for AdhaContextInfo
import 'audio_chat_widget.dart'; // Import audio chat widget
import 'conversations_bottom_sheet.dart'; // Import du bottom sheet des conversations
import '../../auth/bloc/auth_bloc.dart'; // Pour AuthBloc et AuthAuthenticated

class AdhaScreen extends StatefulWidget {
  const AdhaScreen({super.key});

  @override
  State<AdhaScreen> createState() => _AdhaScreenState();
}

class _AdhaScreenState extends State<AdhaScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AdhaMessage? _editingMessage; // To store the message being edited

  /// Liste des pièces jointes en attente d'envoi
  final List<AdhaAttachment> _pendingAttachments = [];

  /// Picker pour les images
  final ImagePicker _imagePicker = ImagePicker();

  /// Contrôle l'auto-scroll pendant le streaming
  /// Si l'utilisateur scrolle manuellement vers le haut, on désactive l'auto-scroll
  bool _autoScrollEnabled = true;

  /// Seuil de distance du bas pour réactiver l'auto-scroll
  static const double _autoScrollThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    // Observer le cycle de vie de l'application pour reconnecter WebSocket
    WidgetsBinding.instance.addObserver(this);

    // Écouter les changements de scroll pour détecter le scroll manuel
    _scrollController.addListener(_onScrollChanged);

    final bloc = context.read<AdhaBloc>();

    // Initialiser le repository ADHA avec l'utilisateur connecté
    // Cela assure que les conversations sont isolées par utilisateur
    _initializeForCurrentUser();

    // Charger les conversations
    bloc.add(const LoadConversations());

    // Connecter au service de streaming selon la documentation (Janvier 2026)
    // La connexion utilise le token JWT récupéré automatiquement
    bloc.add(const ConnectToStreamService());
  }

  /// Initialise le repository ADHA pour l'utilisateur actuellement connecté
  void _initializeForCurrentUser() {
    final authState = context.read<AuthBloc>().state;
    String? userId;

    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    }

    // Initialiser le bloc pour cet utilisateur (isoler les conversations)
    context.read<AdhaBloc>().add(InitializeForUser(userId: userId));
  }

  /// Détecte si l'utilisateur a scrollé manuellement
  /// Si l'utilisateur est proche du bas, on réactive l'auto-scroll
  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // Si l'utilisateur est proche du bas (dans le seuil), réactiver l'auto-scroll
    final isNearBottom = (maxScroll - currentScroll) <= _autoScrollThreshold;

    if (isNearBottom && !_autoScrollEnabled) {
      setState(() => _autoScrollEnabled = true);
    } else if (!isNearBottom && _autoScrollEnabled) {
      // L'utilisateur a scrollé vers le haut, désactiver l'auto-scroll
      setState(() => _autoScrollEnabled = false);
    }
  }

  @override
  void dispose() {
    // Retirer l'observer du cycle de vie
    WidgetsBinding.instance.removeObserver(this);

    // Retirer le listener du scroll
    _scrollController.removeListener(_onScrollChanged);

    _messageController.dispose();
    _scrollController.dispose();

    // Déconnecter du service de streaming selon la documentation (Janvier 2026)
    // Note: La déconnexion complète est gérée par le BLoC.close()
    // Ici on peut optionnellement déclencher la déconnexion si nécessaire
    // context.read<AdhaBloc>().add(const DisconnectFromStreamService());

    super.dispose();
  }

  /// Gère les changements d'état du cycle de vie de l'application
  ///
  /// Reconecte le WebSocket quand l'app revient au premier plan
  /// pour éviter les connexions zombies après un passage en arrière-plan
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // L'app revient au premier plan - reconnecter le WebSocket
      debugPrint(
        '[AdhaScreen] App resumed - vérification de la connexion WebSocket',
      );
      final bloc = context.read<AdhaBloc>();
      bloc.add(const ConnectToStreamService());
    } else if (state == AppLifecycleState.paused) {
      debugPrint(
        '[AdhaScreen] App paused - connexion WebSocket peut être perdue',
      );
    }
  }

  void _scrollToBottom({bool force = false}) {
    // Ne pas auto-scroller si l'utilisateur a scrollé manuellement vers le haut
    // sauf si force=true (ex: envoi d'un nouveau message par l'utilisateur)
    if (!force && !_autoScrollEnabled) return;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Affiche le bottom sheet avec l'historique des conversations
  void _showConversationsHistory(BuildContext context) {
    // Récupérer les conversations depuis le BLoC
    final bloc = context.read<AdhaBloc>();
    bloc.adhaRepository.getConversations().then((conversations) {
      // Trier par date de mise à jour (plus récent en premier)
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      ConversationsBottomSheet.show(
        context: context,
        conversations: conversations,
        onConversationSelected: (conversationId) {
          bloc.add(LoadConversation(conversationId));
        },
        onNewConversation: () {
          // Réinitialiser l'état pour démarrer une nouvelle conversation
          // Cela va émettre AdhaInitial et afficher les suggestions
          final interactionContext = AdhaInteractionContext(
            interactionType: AdhaInteractionType.genericCardAnalysis,
            sourceIdentifier: 'new_conversation_button',
          );
          final contextInfo = AdhaContextInfo(
            baseContext: AdhaBaseContext(
              operationJournalSummary: const AdhaOperationJournalSummary(
                recentEntries: [],
              ),
              businessProfile: const AdhaBusinessProfile(name: 'Entreprise'),
            ),
            interactionContext: interactionContext,
          );
          // NewConversation avec message vide réinitialise l'état vers AdhaInitial
          bloc.add(NewConversation('', contextInfo));
          // Réactiver l'auto-scroll pour la nouvelle conversation
          _autoScrollEnabled = true;
        },
        onDeleteConversation: (conversationId) {
          bloc.add(DeleteConversation(conversationId));
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdhaBloc, AdhaState>(
      builder: (context, adhaState) {
        String currentTitle = "Adha - Assistant IA";
        if (adhaState is AdhaConversationActive) {
          currentTitle =
              adhaState.conversation.title.isNotEmpty
                  ? adhaState.conversation.title
                  : "Nouvelle Conversation";
        }

        List<Widget> appBarActions = [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique des conversations',
            onPressed: () => _showConversationsHistory(context),
          ),
        ];

        return WanzoScaffold(
          currentIndex: 4, // Index for Adha in BottomNavigationBar
          title: currentTitle,
          appBarActions: appBarActions,
          body: Column(
            children: [
              Expanded(
                child: BlocConsumer<AdhaBloc, AdhaState>(
                  listener: (context, state) {
                    if (state is AdhaConversationActive) {
                      // Nouvelle conversation ou réponse complète - scroller vers le bas
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom(),
                      );
                    } else if (state is AdhaStreaming) {
                      // Pendant le streaming, scroller vers le bas si auto-scroll est activé
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom(),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is AdhaInitial) {
                      return _buildFeatureSuggestions(context);
                    } else if (state is AdhaConversationsList &&
                        state.conversations.isEmpty) {
                      return _buildFeatureSuggestions(context);
                    } else if (state is AdhaLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is AdhaError) {
                      return AdhaErrorWidget(
                        errorMessage: state.message,
                        onRetry: () {
                          // Reconnecter au service de streaming
                          context.read<AdhaBloc>().add(
                            ConnectToStreamService(),
                          );
                        },
                        onNewConversation: () {
                          // Démarrer une nouvelle conversation
                          context.read<AdhaBloc>().add(
                            ClearCurrentConversation(),
                          );
                        },
                        onReauth: () {
                          // Naviguer vers l'écran de connexion
                          Navigator.of(context).pushReplacementNamed('/login');
                        },
                      );
                    } else if (state is AdhaStreaming) {
                      // État de streaming: afficher les messages + message en cours
                      return Stack(
                        children: [
                          Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount:
                                      state.conversation.messages.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index <
                                        state.conversation.messages.length) {
                                      final message =
                                          state.conversation.messages[index];
                                      return ChatMessageWidget(
                                        message: message,
                                        onEditMessage: (editedMessage) {
                                          setState(() {
                                            _editingMessage = editedMessage;
                                            _messageController.text =
                                                editedMessage.content;
                                          });
                                        },
                                        onRetryMessage: (failedMessage) {
                                          _retryMessage(
                                            context,
                                            state,
                                            failedMessage,
                                          );
                                        },
                                      );
                                    } else {
                                      // Dernier élément: message en cours de streaming
                                      return StreamingMessageWidget(
                                        partialContent: state.partialContent,
                                        isComplete: !state.isStreaming,
                                        onCancel: () {
                                          // Ne pas envoyer l'ID temporaire local au serveur
                                          // Si isPendingConversationId est true, l'ID n'existe pas encore côté backend
                                          context.read<AdhaBloc>().add(
                                            CancelStreaming(
                                              conversationId:
                                                  state.isPendingConversationId
                                                      ? null
                                                      : state.conversationId,
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          // Bouton flottant "Aller en bas" si l'utilisateur a scrollé vers le haut
                          if (!_autoScrollEnabled && state.isStreaming)
                            Positioned(
                              bottom: 50,
                              right: 16,
                              child: FloatingActionButton.small(
                                onPressed: () {
                                  setState(() => _autoScrollEnabled = true);
                                  _scrollToBottom(force: true);
                                },
                                backgroundColor: Theme.of(context).primaryColor,
                                child: const Icon(
                                  Icons.keyboard_double_arrow_down,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      );
                    } else if (state is AdhaConversationActive) {
                      return state.conversation.messages.isEmpty
                          ? _buildFeatureSuggestions(context)
                          : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: state.conversation.messages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  state.conversation.messages[index];
                              return ChatMessageWidget(
                                message: message,
                                onEditMessage: (editedMessage) {
                                  setState(() {
                                    _editingMessage = editedMessage;
                                    _messageController.text =
                                        editedMessage.content;
                                  });
                                },
                                onRetryMessage: (failedMessage) {
                                  _retryMessage(context, state, failedMessage);
                                },
                              );
                            },
                          );
                    } else if (state is AdhaConversationsList &&
                        state.conversations.isNotEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            "Sélectionnez une conversation (via futur menu) ou démarrez avec les suggestions.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      );
                    }
                    return const Center(child: Text("Préparation d'Adha..."));
                  },
                ),
              ),
              if (adhaState is AdhaConversationActive && adhaState.isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 10),
                        Text("Adha réfléchit..."),
                      ],
                    ),
                  ),
                ),
              // Indicateur de streaming désactivé car déjà géré dans la liste
              // (voir AdhaStreaming case dans le builder ci-dessus)
              _buildInputRow(context, adhaState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputRow(BuildContext context, AdhaState adhaState) {
    bool isConversationActive = adhaState is AdhaConversationActive;
    bool isStreaming = adhaState is AdhaStreaming;
    bool isProcessing = false;
    bool isVoiceActive = false;

    if (isConversationActive) {
      isProcessing = adhaState.isProcessing;
      isVoiceActive = adhaState.isVoiceActive;
    }

    // Pendant le streaming, le bouton se transforme en STOP
    bool canSendMessage =
        !isProcessing &&
        !isVoiceActive &&
        !isStreaming &&
        (_messageController.text.trim().isNotEmpty ||
            _pendingAttachments.isNotEmpty);
    bool canUseAudioMode =
        !isProcessing &&
        !isStreaming; // Audio mode can be used even without active conversation
    // Placeholder for base context that will be populated by the BLoC
    final AdhaBaseContext placeholderBaseContext = AdhaBaseContext(
      operationJournalSummary: const AdhaOperationJournalSummary(
        recentEntries: [],
      ),
      businessProfile: const AdhaBusinessProfile(name: 'Entreprise'),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prévisualisation des pièces jointes (comme WhatsApp/Telegram)
          if (_pendingAttachments.isNotEmpty) _buildAttachmentsPreview(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Bouton d'attachement avec menu
              _buildAttachmentButton(context, isProcessing || isStreaming),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight:
                        150, // Hauteur max avant scroll (environ 6 lignes)
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText:
                          isVoiceActive
                              ? "Parlez maintenant..."
                              : isStreaming
                              ? "ADHA répond..."
                              : (isConversationActive &&
                                  !(adhaState.conversation.messages.isEmpty))
                              ? "Écrivez votre message..."
                              : "Commencer une nouvelle conversation...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null, // Permet au champ de grandir
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    scrollPhysics:
                        const BouncingScrollPhysics(), // Scroll fluide
                    enabled: !isProcessing && !isVoiceActive && !isStreaming,
                    onChanged: (text) {
                      setState(() {});
                    },
                    onSubmitted: (value) {
                      if ((value.trim().isNotEmpty ||
                              _pendingAttachments.isNotEmpty) &&
                          canSendMessage) {
                        _sendMessage(
                          context,
                          adhaState,
                          value.trim(),
                          placeholderBaseContext,
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Bouton unique qui change selon le contexte (style WhatsApp/Telegram):
              // - Input vide → Bouton audio (microphone)
              // - Input avec texte → Bouton envoi
              // - Pendant streaming → Bouton stop
              _buildActionButton(
                context,
                adhaState,
                isStreaming,
                isVoiceActive,
                canSendMessage,
                canUseAudioMode,
                placeholderBaseContext,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construit la prévisualisation des pièces jointes
  Widget _buildAttachmentsPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              _pendingAttachments.asMap().entries.map((entry) {
                final index = entry.key;
                final attachment = entry.value;
                return _buildAttachmentChip(context, attachment, index);
              }).toList(),
        ),
      ),
    );
  }

  /// Construit un chip de pièce jointe avec suppression
  Widget _buildAttachmentChip(
    BuildContext context,
    AdhaAttachment attachment,
    int index,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    IconData icon;
    Color iconColor = primaryColor;

    switch (attachment.type) {
      case AdhaAttachmentType.image:
        icon = Icons.image;
        iconColor = Colors.blue;
        break;
      case AdhaAttachmentType.pdf:
        icon = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case AdhaAttachmentType.document:
        icon = Icons.description;
        iconColor = Colors.orange;
        break;
      case AdhaAttachmentType.spreadsheet:
        icon = Icons.table_chart;
        iconColor = Colors.green;
        break;
      case AdhaAttachmentType.text:
        icon = Icons.text_snippet;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    return Container(
      margin: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Si c'est une image, afficher une miniature
          if (attachment.isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                attachment.contentBytes,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => _buildFileChipContent(
                      icon,
                      iconColor,
                      attachment.name,
                      isDark,
                    ),
              ),
            )
          else
            _buildFileChipContent(icon, iconColor, attachment.name, isDark),
          // Bouton de suppression
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _pendingAttachments.removeAt(index);
                });
              },
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Contenu du chip de fichier
  Widget _buildFileChipContent(
    IconData icon,
    Color iconColor,
    String name,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton d'attachement avec menu d'options
  Widget _buildAttachmentButton(BuildContext context, bool disabled) {
    return PopupMenuButton<String>(
      enabled: !disabled,
      icon: Icon(
        Icons.attach_file,
        color: disabled ? Colors.grey : Theme.of(context).colorScheme.primary,
      ),
      tooltip: 'Joindre un fichier',
      onSelected: (value) => _handleAttachmentSelection(context, value),
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: 'camera',
              child: ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.blue),
                title: Text('Prendre une photo'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'gallery',
              child: ListTile(
                leading: Icon(Icons.photo_library, color: Colors.green),
                title: Text('Galerie'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'document',
              child: ListTile(
                leading: Icon(Icons.insert_drive_file, color: Colors.orange),
                title: Text('Document'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
    );
  }

  /// Gère la sélection d'une option d'attachement
  Future<void> _handleAttachmentSelection(
    BuildContext context,
    String type,
  ) async {
    try {
      switch (type) {
        case 'camera':
          final XFile? image = await _imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
          if (image != null) {
            await _addAttachmentFromFile(image.path, image.name);
          }
          break;
        case 'gallery':
          final List<XFile> images = await _imagePicker.pickMultiImage(
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
          for (final image in images) {
            await _addAttachmentFromFile(image.path, image.name);
          }
          break;
        case 'document':
          final FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              'pdf',
              'doc',
              'docx',
              'xls',
              'xlsx',
              'txt',
              'csv',
              'png',
              'jpg',
              'jpeg',
            ],
            allowMultiple: true,
            withData: true,
          );
          if (result != null) {
            for (final file in result.files) {
              if (file.bytes != null) {
                final attachment = AdhaAttachment.fromBytes(
                  bytes: file.bytes!,
                  name: file.name,
                  mimeType: _getMimeType(file.extension ?? ''),
                );
                setState(() {
                  _pendingAttachments.add(attachment);
                });
              } else if (file.path != null) {
                await _addAttachmentFromFile(file.path!, file.name);
              }
            }
          }
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Ajoute un attachement depuis un chemin de fichier
  Future<void> _addAttachmentFromFile(String path, String name) async {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final extension = path.split('.').last.toLowerCase();
      final attachment = AdhaAttachment.fromBytes(
        bytes: bytes,
        name: name,
        mimeType: _getMimeType(extension),
      );
      setState(() {
        _pendingAttachments.add(attachment);
      });
    }
  }

  /// Obtient le type MIME à partir de l'extension
  String _getMimeType(String extension) {
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }

  /// Construit le bouton d'action unique (audio/envoi/stop) selon le contexte
  /// Pattern UX moderne (WhatsApp, Telegram, iMessage):
  /// - Input vide → Bouton audio (microphone)
  /// - Input avec texte ou pièces jointes → Bouton envoi
  /// - Pendant streaming → Bouton stop
  Widget _buildActionButton(
    BuildContext context,
    AdhaState adhaState,
    bool isStreaming,
    bool isVoiceActive,
    bool canSendMessage,
    bool canUseAudioMode,
    AdhaBaseContext placeholderBaseContext,
  ) {
    final bool hasText = _messageController.text.trim().isNotEmpty;
    final bool hasAttachments = _pendingAttachments.isNotEmpty;
    final primaryColor = Theme.of(context).primaryColor;

    // 1. Pendant le streaming → Bouton STOP
    if (isStreaming) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: FloatingActionButton(
              onPressed: () {
                if (adhaState is AdhaStreaming) {
                  // Ne pas envoyer l'ID temporaire local au serveur
                  // Si isPendingConversationId est true, l'ID n'existe pas encore côté backend
                  context.read<AdhaBloc>().add(
                    CancelStreaming(
                      conversationId:
                          adhaState.isPendingConversationId
                              ? null
                              : adhaState.conversationId,
                    ),
                  );
                }
              },
              backgroundColor: Colors.red.shade400,
              elevation: 2,
              mini: true,
              heroTag: 'adhaActionFab',
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          );
        },
      );
    }

    // 2. Texte ou pièces jointes dans l'input → Bouton ENVOI avec animation de transition
    if (hasText || hasAttachments) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 150),
        tween: Tween(begin: 0.8, end: 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: FloatingActionButton(
              onPressed:
                  canSendMessage
                      ? () {
                        final message = _messageController.text.trim();
                        if (message.isNotEmpty) {
                          _sendMessage(
                            context,
                            adhaState,
                            message,
                            placeholderBaseContext,
                          );
                        }
                      }
                      : null,
              backgroundColor: canSendMessage ? primaryColor : Colors.grey,
              elevation: 2,
              mini: true,
              heroTag: 'adhaActionFab',
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          );
        },
      );
    }

    // 3. Input vide → Bouton AUDIO (microphone) avec animation
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 150),
      tween: Tween(begin: 0.8, end: 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: FloatingActionButton(
            onPressed:
                canUseAudioMode
                    ? () {
                      final adhaBloc = context.read<AdhaBloc>();
                      if (isVoiceActive) {
                        adhaBloc.add(const StopVoiceRecognition());
                      } else {
                        // Ouvrir le mode audio conversationnel full-duplex
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (modalContext) {
                            return BlocProvider.value(
                              value: adhaBloc,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.6,
                                  minHeight: 300,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                child: const AudioChatWidget(),
                              ),
                            );
                          },
                        );
                      }
                    }
                    : null,
            backgroundColor:
                isVoiceActive
                    ? Colors.red.shade400
                    : (canUseAudioMode ? primaryColor : Colors.grey),
            elevation: 2,
            mini: true,
            heroTag: 'adhaActionFab',
            child: Icon(
              isVoiceActive ? Icons.graphic_eq : Icons.mic,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  /// Envoie un message avec le contexte approprié et les pièces jointes
  void _sendMessage(
    BuildContext context,
    AdhaState adhaState,
    String message,
    AdhaBaseContext placeholderBaseContext,
  ) {
    // Réactiver l'auto-scroll quand l'utilisateur envoie un message
    setState(() {
      _autoScrollEnabled = true;
    });

    AdhaInteractionType interactionType;
    String sourceIdentifier;

    if (adhaState is AdhaConversationActive &&
        adhaState.conversation.messages.isNotEmpty) {
      interactionType = AdhaInteractionType.followUp;
      sourceIdentifier = 'text_input_follow_up';
    } else {
      interactionType = AdhaInteractionType.genericCardAnalysis;
      sourceIdentifier = 'text_input_initiation';
    }

    final interactionContext = AdhaInteractionContext(
      interactionType: interactionType,
      sourceIdentifier: sourceIdentifier,
    );
    final contextInfo = AdhaContextInfo(
      baseContext: placeholderBaseContext,
      interactionContext: interactionContext,
    );

    // Récupérer les pièces jointes avant de les effacer
    final attachments = List<AdhaAttachment>.from(_pendingAttachments);

    // If editing, send an EditMessage event, otherwise use streaming
    if (_editingMessage != null) {
      context.read<AdhaBloc>().add(
        EditMessage(_editingMessage!.id, message, contextInfo),
      );
      setState(() {
        _editingMessage = null; // Reset editing state
        _pendingAttachments.clear();
      });
    } else {
      // Utiliser le streaming par défaut selon la documentation (Janvier 2026)
      context.read<AdhaBloc>().add(
        SendStreamingMessage(
          message,
          contextInfo: contextInfo,
          streaming: true,
          attachments: attachments.isNotEmpty ? attachments : null,
        ),
      );
      setState(() {
        _pendingAttachments.clear();
      });
    }
    _messageController.clear();

    // Forcer le scroll vers le bas après l'envoi
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(force: true),
    );
  }

  AdhaBaseContext _buildPlaceholderBaseContext() {
    return AdhaBaseContext(
      operationJournalSummary: const AdhaOperationJournalSummary(
        recentEntries: [],
      ),
      businessProfile: const AdhaBusinessProfile(name: 'Entreprise'),
    );
  }

  void _retryMessage(
    BuildContext context,
    AdhaState adhaState,
    AdhaMessage failedMessage,
  ) {
    final originalMessage =
        failedMessage.contextInfo?['originalMessage'] as String?;
    if (originalMessage == null || originalMessage.trim().isEmpty) {
      return;
    }

    _sendMessage(
      context,
      adhaState,
      originalMessage,
      _buildPlaceholderBaseContext(),
    );
  }

  Widget _buildFeatureSuggestions(BuildContext context) {
    final AdhaBaseContext placeholderBaseContext = AdhaBaseContext(
      operationJournalSummary: const AdhaOperationJournalSummary(
        recentEntries: [],
      ),
      businessProfile: const AdhaBusinessProfile(name: 'Entreprise'),
    );
    final List<Map<String, dynamic>> features = [
      {
        'icon': Icons.analytics,
        'title': "Analyses de ventes",
        'description': "Quelles sont mes ventes du mois dernier ?",
        'prompt': "Montre-moi les analyses de ventes du mois dernier.",
      },
      {
        'icon': Icons.inventory_2,
        'title': "Gestion de stock",
        'description': "Quels produits sont en faible stock ?",
        'prompt': "Liste les produits avec un stock faible.",
      },
      {
        'icon': Icons.people,
        'title': "Relations clients",
        'description': "Donne-moi des conseils pour fidéliser mes clients.",
        'prompt': "Comment puis-je améliorer la fidélisation de mes clients ?",
      },
      {
        'icon': Icons.calculate,
        'title': "Calculs financiers",
        'description': "Calcule ma marge brute pour le produit X.",
        'prompt': "Calcule la marge brute pour le produit X.",
      },
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Que puis-je faire pour vous aujourd'hui ?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: features.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final feature = features[index];
                return InkWell(
                  onTap: () {
                    final interactionContext = AdhaInteractionContext(
                      interactionType: AdhaInteractionType.genericCardAnalysis,
                      sourceIdentifier:
                          'suggestion_card_${feature['title']?.toString().replaceAll(' ', '_').toLowerCase() ?? 'unknown'}',
                      interactionData: {
                        'cardTitle': feature['title'],
                        'cardPrompt': feature['prompt'],
                      },
                    );
                    final contextInfo = AdhaContextInfo(
                      baseContext: placeholderBaseContext,
                      interactionContext: interactionContext,
                    );
                    // Utiliser le streaming par défaut selon la documentation (Janvier 2026)
                    context.read<AdhaBloc>().add(
                      SendStreamingMessage(
                        feature['prompt'] as String,
                        contextInfo: contextInfo,
                        streaming: true,
                      ),
                    );
                  },
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            feature['icon'] as IconData,
                            size: 36,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            feature['title'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            feature['description'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
