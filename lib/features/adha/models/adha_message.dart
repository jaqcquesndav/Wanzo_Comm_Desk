import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'adha_message.g.dart';

/// Expéditeur du message selon l'API backend
@HiveType(typeId: 103)
enum AdhaMessageSender {
  @HiveField(0)
  user('user'),
  @HiveField(1)
  ai('ai');

  final String value;
  const AdhaMessageSender(this.value);

  static AdhaMessageSender fromString(String value) {
    return AdhaMessageSender.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AdhaMessageSender.ai,
    );
  }
}

/// Types de contenu de message supportés par Adha
@HiveType(typeId: 101)
enum AdhaMessageType {
  /// Message texte simple
  @HiveField(0)
  text,

  /// Formule mathématique (LaTeX)
  @HiveField(1)
  latex,

  /// Graphique (généré à partir de code Python)
  @HiveField(2)
  graph,

  /// Code avec coloration syntaxique
  @HiveField(3)
  code,

  /// Message multimédia (image, audio)
  @HiveField(4)
  media,
}

/// Message envoyé ou reçu dans la conversation avec Adha
/// Correspond au modèle AdhaMessage (Entity) du backend
@HiveType(typeId: 100)
class AdhaMessage extends Equatable {
  /// ID unique du message (UUID)
  @HiveField(0)
  final String id;

  /// Contenu du message (appelé 'text' dans l'API backend)
  @HiveField(1)
  final String content;

  /// Date d'envoi du message
  @HiveField(2)
  final DateTime timestamp;

  /// Expéditeur du message ('user' ou 'ai')
  @HiveField(3)
  final AdhaMessageSender sender;

  /// Type de contenu du message (pour le rendu)
  @HiveField(4)
  final AdhaMessageType type;

  /// Contexte associé au message (nullable)
  @HiveField(5)
  final Map<String, dynamic>? contextInfo;

  const AdhaMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.sender,
    this.type = AdhaMessageType.text,
    this.contextInfo,
  });

  /// Getter de compatibilité pour l'ancien code
  bool get isUserMessage => sender == AdhaMessageSender.user;

  @override
  List<Object?> get props => [
    id,
    content,
    timestamp,
    sender,
    type,
    contextInfo,
  ];

  /// Factory pour créer depuis la réponse JSON de l'API backend
  factory AdhaMessage.fromJson(Map<String, dynamic> json) {
    // Support des deux formats: 'text' (backend) et 'content' (local)
    final text = json['text'] ?? json['content'] as String;

    // Support des deux formats: 'sender' (backend) et 'isUserMessage' (local)
    AdhaMessageSender messageSender;
    if (json.containsKey('sender')) {
      messageSender = AdhaMessageSender.fromString(json['sender'] as String);
    } else if (json.containsKey('isUserMessage')) {
      messageSender =
          json['isUserMessage'] as bool
              ? AdhaMessageSender.user
              : AdhaMessageSender.ai;
    } else {
      messageSender = AdhaMessageSender.ai;
    }

    return AdhaMessage(
      id: json['id'] as String,
      content: text,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sender: messageSender,
      type:
          json['type'] != null
              ? AdhaMessageType.values.firstWhere(
                (e) => e.toString() == 'AdhaMessageType.${json['type']}',
                orElse: () => AdhaMessageType.text,
              )
              : AdhaMessageType.text,
      contextInfo: json['contextInfo'] as Map<String, dynamic>?,
    );
  }

  /// Convertit en JSON pour l'API backend
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': content, // Utilise 'text' pour le backend
    'timestamp': timestamp.toIso8601String(),
    'sender': sender.value,
    'type': type.toString().split('.').last,
    if (contextInfo != null) 'contextInfo': contextInfo,
  };

  /// Convertit en JSON pour le stockage local Hive
  Map<String, dynamic> toLocalJson() => {
    'id': id,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'isUserMessage': isUserMessage,
    'type': type.toString().split('.').last,
    if (contextInfo != null) 'contextInfo': contextInfo,
  };

  AdhaMessage copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    AdhaMessageSender? sender,
    AdhaMessageType? type,
    Map<String, dynamic>? contextInfo,
  }) {
    return AdhaMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      contextInfo: contextInfo ?? this.contextInfo,
    );
  }
}

/// Conversation avec l'assistant Adha
@HiveType(typeId: 102)
class AdhaConversation extends Equatable {
  /// ID unique de la conversation
  @HiveField(0)
  final String id;

  /// Titre de la conversation
  @HiveField(1)
  final String title;

  /// Date de création de la conversation
  @HiveField(2)
  final DateTime createdAt;

  /// Date de la dernière mise à jour
  @HiveField(3)
  final DateTime updatedAt;

  /// Liste des messages de la conversation
  @HiveField(4)
  final List<AdhaMessage> messages;

  /// Informations de contexte initiales pour cette conversation
  /// Peut être null si le contexte n'est pas applicable ou déjà traité
  @HiveField(5)
  final Map<String, dynamic>? initialContextJson; // Stocke le JSON du AdhaContextInfo initial

  const AdhaConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.initialContextJson, // Ajouté au constructeur
  });

  AdhaConversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AdhaMessage>? messages,
    Map<String, dynamic>? initialContextJson,
    bool clearInitialContext =
        false, // Pour explicitement nullifier le contexte
  }) {
    return AdhaConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      initialContextJson:
          clearInitialContext
              ? null
              : initialContextJson ?? this.initialContextJson,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    createdAt,
    updatedAt,
    messages,
    initialContextJson,
  ];
}
