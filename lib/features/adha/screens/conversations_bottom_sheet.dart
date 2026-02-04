import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/adha_message.dart';

/// Widget bottom sheet discret pour afficher l'historique des conversations ADHA
/// S'affiche via un DraggableScrollableSheet pour une expérience similaire
/// au sélecteur de types de vente
class ConversationsBottomSheet extends StatelessWidget {
  /// Liste des conversations
  final List<AdhaConversation> conversations;

  /// Callback lorsqu'une conversation est sélectionnée
  final Function(String conversationId) onConversationSelected;

  /// Callback pour créer une nouvelle conversation
  final VoidCallback onNewConversation;

  /// Callback lorsqu'une conversation est supprimée
  final Function(String conversationId)? onDeleteConversation;

  const ConversationsBottomSheet({
    super.key,
    required this.conversations,
    required this.onConversationSelected,
    required this.onNewConversation,
    this.onDeleteConversation,
  });

  /// Affiche le bottom sheet des conversations
  static Future<void> show({
    required BuildContext context,
    required List<AdhaConversation> conversations,
    required Function(String) onConversationSelected,
    required VoidCallback onNewConversation,
    Function(String)? onDeleteConversation,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ConversationsBottomSheet(
            conversations: conversations,
            onConversationSelected: onConversationSelected,
            onNewConversation: onNewConversation,
            onDeleteConversation: onDeleteConversation,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Barre de drag
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Conversations',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Bouton nouvelle conversation - discret (juste une icône)
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onNewConversation();
                      },
                      icon: Icon(
                        Icons.add_circle_outline,
                        size: 22,
                        color: Colors.grey[500],
                      ),
                      tooltip: 'Nouvelle conversation',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Liste des conversations
              Expanded(
                child:
                    conversations.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: conversations.length,
                          separatorBuilder:
                              (_, __) => const Divider(height: 1, indent: 72),
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            return _buildConversationTile(
                              context,
                              conversation,
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez une nouvelle discussion avec ADHA',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    AdhaConversation conversation,
  ) {
    final theme = Theme.of(context);
    final lastMessage =
        conversation.messages.isNotEmpty ? conversation.messages.last : null;

    // Formater la date
    String formattedDate = '';
    if (lastMessage != null) {
      final now = DateTime.now();
      final diff = now.difference(lastMessage.timestamp);

      if (diff.inDays == 0) {
        formattedDate = DateFormat.Hm().format(lastMessage.timestamp);
      } else if (diff.inDays == 1) {
        formattedDate = 'Hier';
      } else if (diff.inDays < 7) {
        formattedDate = DateFormat.E('fr').format(lastMessage.timestamp);
      } else {
        formattedDate = DateFormat.MMMd('fr').format(lastMessage.timestamp);
      }
    }

    return Dismissible(
      key: Key(conversation.id),
      direction:
          onDeleteConversation != null
              ? DismissDirection.endToStart
              : DismissDirection.none,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Supprimer'),
                content: const Text(
                  'Voulez-vous vraiment supprimer cette conversation ?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
        );
      },
      onDismissed: (_) {
        onDeleteConversation?.call(conversation.id);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: theme.primaryColor.withOpacity(0.1),
          child: Icon(
            Icons.smart_toy_outlined,
            color: theme.primaryColor,
            size: 22,
          ),
        ),
        title: Text(
          conversation.title.isNotEmpty ? conversation.title : 'Conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle:
            lastMessage != null
                ? Text(
                  lastMessage.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                )
                : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (formattedDate.isNotEmpty)
              Text(
                formattedDate,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            const SizedBox(height: 4),
            Text(
              '${conversation.messages.length} msg',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          onConversationSelected(conversation.id);
        },
      ),
    );
  }
}
