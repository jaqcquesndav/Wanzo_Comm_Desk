import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../bloc/adha_bloc.dart';
import '../bloc/adha_event.dart';
import '../bloc/adha_state.dart';
import '../models/adha_message.dart';
import '../models/adha_attachment.dart';
import '../widgets/adha_error_widget.dart';
import '../screens/chat_message_widget.dart';
import '../screens/streaming_message_widget.dart';
import '../screens/audio_chat_widget.dart';
import '../models/adha_context_info.dart';
import '../screens/conversations_bottom_sheet.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../constants/colors.dart';

/// Widget du panneau chat Adha pour affichage dans le layout split
/// Ce widget contient uniquement le contenu du chat sans scaffold
class AdhaChatPanel extends StatefulWidget {
  /// Callback pour afficher l'historique des conversations
  final VoidCallback? onShowHistory;

  const AdhaChatPanel({super.key, this.onShowHistory});

  @override
  State<AdhaChatPanel> createState() => _AdhaChatPanelState();
}

class _AdhaChatPanelState extends State<AdhaChatPanel>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AdhaMessage? _editingMessage;
  final List<AdhaAttachment> _pendingAttachments = [];
  bool _autoScrollEnabled = true;
  static const double _autoScrollThreshold = 100.0;
  bool _hasText = false; // Pour suivre si le champ de saisie contient du texte

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScrollChanged);
    _messageController.addListener(
      _onTextChanged,
    ); // Écouter les changements de texte

    final bloc = context.read<AdhaBloc>();
    _initializeForCurrentUser();
    bloc.add(const LoadConversations());
    bloc.add(const ConnectToStreamService());
  }

  /// Callback quand le texte change dans le champ de saisie
  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _initializeForCurrentUser() {
    final authState = context.read<AuthBloc>().state;
    String? userId;
    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    }
    context.read<AdhaBloc>().add(InitializeForUser(userId: userId));
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    final isNearBottom = (maxScroll - currentScroll) <= _autoScrollThreshold;

    if (isNearBottom && !_autoScrollEnabled) {
      setState(() => _autoScrollEnabled = true);
    } else if (!isNearBottom && _autoScrollEnabled) {
      setState(() => _autoScrollEnabled = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScrollChanged);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      context.read<AdhaBloc>().add(const ConnectToStreamService());
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_autoScrollEnabled) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showConversationsHistory(BuildContext context) {
    final bloc = context.read<AdhaBloc>();
    final currentContext = context;
    bloc.adhaRepository.getConversations().then((conversations) {
      if (!mounted) return;
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      ConversationsBottomSheet.show(
        context: currentContext,
        conversations: conversations,
        onConversationSelected: (conversationId) {
          bloc.add(LoadConversation(conversationId));
        },
        onNewConversation: () {
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
          bloc.add(NewConversation('', contextInfo));
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Toolbar du chat
          _buildChatToolbar(context, theme, isDark),

          // Zone de messages
          Expanded(
            child: BlocConsumer<AdhaBloc, AdhaState>(
              listener: (context, state) {
                if (state is AdhaConversationActive || state is AdhaStreaming) {
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
                } else if (state is AdhaConversationActive) {
                  return _buildMessagesList(
                    state.conversation.messages,
                    false,
                    null,
                  );
                } else if (state is AdhaStreaming) {
                  return _buildMessagesList(
                    state.conversation.messages,
                    true,
                    state.partialContent,
                  );
                } else if (state is AdhaError) {
                  return AdhaErrorWidget(
                    errorMessage: state.message,
                    onRetry: () {
                      context.read<AdhaBloc>().add(const LoadConversations());
                    },
                  );
                }
                return _buildFeatureSuggestions(context);
              },
            ),
          ),

          // Pièces jointes en attente
          if (_pendingAttachments.isNotEmpty) _buildPendingAttachments(context),

          // Zone de saisie
          _buildInputArea(context, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildChatToolbar(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color:
                isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.3)
                    : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Bouton nouvelle conversation
          _buildToolbarButton(
            icon: Icons.add,
            tooltip: 'Nouvelle conversation',
            onPressed: () {
              final bloc = context.read<AdhaBloc>();
              final interactionContext = AdhaInteractionContext(
                interactionType: AdhaInteractionType.genericCardAnalysis,
                sourceIdentifier: 'new_chat_button',
              );
              final contextInfo = AdhaContextInfo(
                baseContext: AdhaBaseContext(
                  operationJournalSummary: const AdhaOperationJournalSummary(
                    recentEntries: [],
                  ),
                  businessProfile: const AdhaBusinessProfile(
                    name: 'Entreprise',
                  ),
                ),
                interactionContext: interactionContext,
              );
              bloc.add(NewConversation('', contextInfo));
              _autoScrollEnabled = true;
            },
          ),

          // Bouton historique
          _buildToolbarButton(
            icon: Icons.history,
            tooltip: 'Historique',
            onPressed:
                widget.onShowHistory ??
                () => _showConversationsHistory(context),
          ),

          const Spacer(),

          // Indicateur de connexion
          BlocBuilder<AdhaBloc, AdhaState>(
            builder: (context, state) {
              final isConnected =
                  state is AdhaConversationActive ||
                  state is AdhaStreaming ||
                  state is AdhaInitial;
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureSuggestions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final suggestions = [
      {
        'icon': Icons.analytics_outlined,
        'title': 'Analyser mes ventes',
        'prompt': 'Analyse mes ventes de cette semaine',
      },
      {
        'icon': Icons.inventory_2_outlined,
        'title': 'État du stock',
        'prompt': 'Montre-moi les produits en rupture de stock',
      },
      {
        'icon': Icons.trending_up_outlined,
        'title': 'Performance',
        'prompt': 'Comment se porte mon entreprise ce mois-ci ?',
      },
      {
        'icon': Icons.receipt_long_outlined,
        'title': 'Dépenses récentes',
        'prompt': 'Résume mes dépenses du mois',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Center(
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: WanzoColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 30,
                    color: WanzoColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Comment puis-je vous aider ?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Posez une question ou choisissez une suggestion',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Suggestions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                suggestions.map((suggestion) {
                  return InkWell(
                    onTap:
                        () => _sendSuggestion(suggestion['prompt'] as String),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.grey[800]?.withValues(alpha: 0.5)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.grey[700]!.withValues(alpha: 0.5)
                                  : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            suggestion['icon'] as IconData,
                            size: 16,
                            color: WanzoColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            suggestion['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  void _sendSuggestion(String prompt) {
    _messageController.text = prompt;
    _sendMessage();
  }

  Widget _buildMessagesList(
    List<AdhaMessage> messages,
    bool isStreaming,
    String? streamedContent,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length + (isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (isStreaming && index == messages.length) {
          return StreamingMessageWidget(partialContent: streamedContent ?? '');
        }

        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatMessageWidget(
            message: message,
            onEditMessage:
                message.isUserMessage
                    ? (msg) {
                      setState(() {
                        _editingMessage = msg;
                        _messageController.text = msg.content;
                      });
                    }
                    : null,
          ),
        );
      },
    );
  }

  Widget _buildPendingAttachments(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        itemBuilder: (context, index) {
          final attachment = _pendingAttachments[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getAttachmentIcon(attachment.type),
                  size: 16,
                  color: WanzoColors.primary,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Text(
                    attachment.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() {
                      _pendingAttachments.removeAt(index);
                    });
                  },
                  child: Icon(Icons.close, size: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getAttachmentIcon(AdhaAttachmentType type) {
    switch (type) {
      case AdhaAttachmentType.image:
        return Icons.image_outlined;
      case AdhaAttachmentType.pdf:
        return Icons.picture_as_pdf_outlined;
      case AdhaAttachmentType.document:
        return Icons.description_outlined;
      case AdhaAttachmentType.spreadsheet:
        return Icons.table_chart_outlined;
      default:
        return Icons.attach_file;
    }
  }

  Widget _buildInputArea(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color:
                isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.5)
                    : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bouton pièces jointes
          IconButton(
            icon: Icon(
              Icons.attach_file,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            onPressed: _pickAttachment,
            tooltip: 'Joindre un fichier',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          const SizedBox(width: 8),

          // Champ de saisie
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isDark
                          ? Colors.grey[700]!.withValues(alpha: 0.5)
                          : Colors.grey[300]!,
                ),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:
                      _editingMessage != null
                          ? 'Modifier votre message...'
                          : 'Posez votre question...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Bouton dynamique: Micro / Envoyer / Stop
          BlocBuilder<AdhaBloc, AdhaState>(
            builder: (context, state) {
              final isStreaming = state is AdhaStreaming;
              final isLoading = state is AdhaLoading;
              final isEditing = _editingMessage != null;

              // Déterminer l'état du bouton
              // 1. Si l'IA répond (streaming) → Bouton Stop
              // 2. Si on édite un message → Bouton Check
              // 3. Si le champ contient du texte → Bouton Envoyer
              // 4. Sinon → Bouton Microphone (mode audio)

              if (isStreaming) {
                // Bouton STOP pendant le streaming
                return _buildDynamicButton(
                  icon: Icons.stop_rounded,
                  color: Colors.red,
                  tooltip: 'Arrêter la réponse',
                  onPressed: () {
                    context.read<AdhaBloc>().add(const InterruptAdha());
                  },
                );
              } else if (isEditing) {
                // Bouton CONFIRMER pendant l'édition
                return _buildDynamicButton(
                  icon: Icons.check,
                  color: WanzoColors.primary,
                  tooltip: 'Confirmer',
                  onPressed: isLoading ? null : _sendMessage,
                );
              } else if (_hasText || _pendingAttachments.isNotEmpty) {
                // Bouton ENVOYER quand il y a du texte
                return _buildDynamicButton(
                  icon: Icons.send,
                  color: WanzoColors.primary,
                  tooltip: 'Envoyer',
                  onPressed: isLoading ? null : _sendMessage,
                );
              } else {
                // Bouton MICROPHONE par défaut (champ vide)
                return _buildDynamicButton(
                  icon: Icons.mic,
                  color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                  tooltip: 'Mode vocal',
                  onPressed: isLoading ? null : _openAudioMode,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Construit le bouton dynamique avec animation
  Widget _buildDynamicButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: IconButton(
        key: ValueKey(icon),
        icon: Icon(icon, color: onPressed == null ? Colors.grey : color),
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  /// Ouvre le mode audio pour conversation vocale avec ADHA
  void _openAudioMode() {
    final adhaBloc = context.read<AdhaBloc>();
    // Afficher le widget audio en modal bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BlocProvider.value(
            value: adhaBloc,
            child: const AudioChatWidget(),
          ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final bloc = context.read<AdhaBloc>();

    if (_editingMessage != null) {
      final interactionContext = AdhaInteractionContext(
        interactionType: AdhaInteractionType.genericCardAnalysis,
        sourceIdentifier: 'edit_message',
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
      bloc.add(EditMessage(_editingMessage!.id, text, contextInfo));
      setState(() => _editingMessage = null);
    } else {
      final interactionContext = AdhaInteractionContext(
        interactionType: AdhaInteractionType.genericCardAnalysis,
        sourceIdentifier: 'chat_panel',
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

      // Récupérer les pièces jointes avant de les effacer
      final attachments = List<AdhaAttachment>.from(_pendingAttachments);

      // Utiliser le streaming par défaut selon la documentation (Janvier 2026)
      bloc.add(
        SendStreamingMessage(
          text,
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
    _autoScrollEnabled = true;
    _scrollToBottom(force: true);
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
      ],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            final type = _getAttachmentTypeFromExtension(file.extension ?? '');
            final mimeType = _getMimeTypeFromExtension(file.extension ?? '');
            _pendingAttachments.add(
              AdhaAttachment(
                name: file.name,
                type: type,
                localPath: file.path,
                size: file.size,
                mimeType: mimeType,
                content: '', // Le contenu sera chargé lors de l'envoi
              ),
            );
          }
        }
      });
    }
  }

  String _getMimeTypeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
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
      default:
        return 'application/octet-stream';
    }
  }

  AdhaAttachmentType _getAttachmentTypeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
        return AdhaAttachmentType.image;
      case 'pdf':
        return AdhaAttachmentType.pdf;
      case 'doc':
      case 'docx':
        return AdhaAttachmentType.document;
      case 'xls':
      case 'xlsx':
        return AdhaAttachmentType.spreadsheet;
      default:
        return AdhaAttachmentType.other;
    }
  }
}
