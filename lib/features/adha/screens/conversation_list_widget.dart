import 'package:flutter/material.dart';
import '../models/adha_message.dart';

/// Widget pour afficher la liste des conversations avec Adha
class ConversationListWidget extends StatelessWidget {
  /// Liste des conversations
  final List<AdhaConversation> conversations;
  
  /// Callback lorsqu'une conversation est sélectionnée
  final Function(String) onConversationSelected;
  
  /// Callback lorsqu'une conversation est supprimée
  final Function(String) onDeleteConversation;

  const ConversationListWidget({
    super.key,
    required this.conversations,
    required this.onConversationSelected,
    required this.onDeleteConversation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // En-tête du drawer
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            bottom: 16,
            left: 16,
            right: 16,
          ),
          color: Theme.of(context).primaryColor,
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 24,
                child: Icon(
                  Icons.smart_toy,
                  color: Colors.purple,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Adha",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Votre assistant IA",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Liste des conversations
        Expanded(
          child: conversations.isEmpty
              ? const Center(
                  child: Text(
                    "Aucune conversation",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return _buildConversationTile(context, conversation);
                  },
                ),
        ),
      ],
    );
  }

  /// Construit un élément de la liste des conversations
  Widget _buildConversationTile(BuildContext context, AdhaConversation conversation) {
    // Récupère le dernier message pour l'aperçu
    final lastMessage = conversation.messages.isNotEmpty
        ? conversation.messages.last
        : null;
    
    return Dismissible(
      key: Key(conversation.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Supprimer la conversation"),
            content: const Text("Êtes-vous sûr de vouloir supprimer cette conversation ?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Annuler"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Supprimer"),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        onDeleteConversation(conversation.id);
      },
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.purple,
          child: Icon(
            Icons.chat,
            color: Colors.white,
            size: 18,
          ),
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: lastMessage != null
            ? Text(
                lastMessage.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : const Text("Nouvelle conversation"),
        trailing: Text(
          _formatDate(conversation.updatedAt),
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        onTap: () => onConversationSelected(conversation.id),
      ),
    );
  }

  /// Formatte la date de la conversation
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (dateOnly == yesterday) {
      return "Hier";
    } else {
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }
  }
}
