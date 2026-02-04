import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/adha_message.dart';
import '../models/adha_context_info.dart';
import '../models/adha_stream_models.dart';

// ============================================================================
// ADAPTATEURS POUR ADHAMESSAGE ET ADHACONVERSATION
// ============================================================================

/// Adaptateur Hive pour AdhaMessage
///
/// TypeID: 100
///
/// Structure de stockage (v2 - Janvier 2026):
/// - id: String
/// - content: String
/// - timestamp: int (milliseconds since epoch)
/// - senderIndex: int (AdhaMessageSender enum index)
/// - typeIndex: int (AdhaMessageType enum index)
/// - hasContextInfo: bool
/// - contextInfoJson: String? (JSON encoded)
class AdhaMessageAdapter extends TypeAdapter<AdhaMessage> {
  @override
  final int typeId = 100;

  @override
  AdhaMessage read(BinaryReader reader) {
    final numFields = reader.readByte();

    String id = '';
    String content = '';
    DateTime timestamp = DateTime.now();
    AdhaMessageSender sender = AdhaMessageSender.ai;
    AdhaMessageType type = AdhaMessageType.text;
    Map<String, dynamic>? contextInfo;

    for (int i = 0; i < numFields; i++) {
      final fieldId = reader.readByte();
      switch (fieldId) {
        case 0:
          id = reader.readString();
          break;
        case 1:
          content = reader.readString();
          break;
        case 2:
          timestamp = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
          break;
        case 3:
          // Support ancien format (bool) et nouveau format (int)
          final value = reader.read();
          if (value is bool) {
            sender = value ? AdhaMessageSender.user : AdhaMessageSender.ai;
          } else if (value is int) {
            sender = AdhaMessageSender.values[value];
          }
          break;
        case 4:
          type = AdhaMessageType.values[reader.readInt()];
          break;
        case 5:
          final hasContext = reader.readBool();
          if (hasContext) {
            final jsonStr = reader.readString();
            contextInfo = jsonDecode(jsonStr) as Map<String, dynamic>;
          }
          break;
      }
    }

    return AdhaMessage(
      id: id,
      content: content,
      timestamp: timestamp,
      sender: sender,
      type: type,
      contextInfo: contextInfo,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaMessage obj) {
    writer.writeByte(6); // Nombre de champs

    // Field 0: id
    writer.writeByte(0);
    writer.writeString(obj.id);

    // Field 1: content
    writer.writeByte(1);
    writer.writeString(obj.content);

    // Field 2: timestamp
    writer.writeByte(2);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);

    // Field 3: sender (as int)
    writer.writeByte(3);
    writer.writeInt(obj.sender.index);

    // Field 4: type
    writer.writeByte(4);
    writer.writeInt(obj.type.index);

    // Field 5: contextInfo
    writer.writeByte(5);
    if (obj.contextInfo != null) {
      writer.writeBool(true);
      writer.writeString(jsonEncode(obj.contextInfo));
    } else {
      writer.writeBool(false);
    }
  }
}

/// Adaptateur Hive pour AdhaMessageType
///
/// TypeID: 101
class AdhaMessageTypeAdapter extends TypeAdapter<AdhaMessageType> {
  @override
  final int typeId = 101;

  @override
  AdhaMessageType read(BinaryReader reader) {
    return AdhaMessageType.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, AdhaMessageType obj) {
    writer.writeInt(obj.index);
  }
}

/// Adaptateur Hive pour AdhaMessageSender
///
/// TypeID: 103
class AdhaMessageSenderAdapter extends TypeAdapter<AdhaMessageSender> {
  @override
  final int typeId = 103;

  @override
  AdhaMessageSender read(BinaryReader reader) {
    return AdhaMessageSender.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, AdhaMessageSender obj) {
    writer.writeInt(obj.index);
  }
}

/// Adaptateur Hive pour AdhaConversation
///
/// TypeID: 102
///
/// Structure de stockage (v2 - Janvier 2026):
/// - id: String
/// - title: String
/// - createdAt: int (milliseconds since epoch)
/// - updatedAt: int (milliseconds since epoch)
/// - messagesLength: int
/// - messages: List<AdhaMessage>
/// - hasInitialContext: bool
/// - initialContextJson: String? (JSON encoded)
class AdhaConversationAdapter extends TypeAdapter<AdhaConversation> {
  @override
  final int typeId = 102;

  @override
  AdhaConversation read(BinaryReader reader) {
    final numFields = reader.readByte();

    String id = '';
    String title = '';
    DateTime createdAt = DateTime.now();
    DateTime updatedAt = DateTime.now();
    List<AdhaMessage> messages = [];
    Map<String, dynamic>? initialContextJson;

    for (int i = 0; i < numFields; i++) {
      final fieldId = reader.readByte();
      switch (fieldId) {
        case 0:
          id = reader.readString();
          break;
        case 1:
          title = reader.readString();
          break;
        case 2:
          createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
          break;
        case 3:
          updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
          break;
        case 4:
          final messagesLength = reader.readInt();
          messages = <AdhaMessage>[];
          for (var j = 0; j < messagesLength; j++) {
            messages.add(reader.read() as AdhaMessage);
          }
          break;
        case 5:
          final hasContext = reader.readBool();
          if (hasContext) {
            final jsonStr = reader.readString();
            initialContextJson = jsonDecode(jsonStr) as Map<String, dynamic>;
          }
          break;
      }
    }

    return AdhaConversation(
      id: id,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      messages: messages,
      initialContextJson: initialContextJson,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaConversation obj) {
    writer.writeByte(6); // Nombre de champs

    // Field 0: id
    writer.writeByte(0);
    writer.writeString(obj.id);

    // Field 1: title
    writer.writeByte(1);
    writer.writeString(obj.title);

    // Field 2: createdAt
    writer.writeByte(2);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);

    // Field 3: updatedAt
    writer.writeByte(3);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);

    // Field 4: messages
    writer.writeByte(4);
    writer.writeInt(obj.messages.length);
    for (var message in obj.messages) {
      writer.write(message);
    }

    // Field 5: initialContextJson
    writer.writeByte(5);
    if (obj.initialContextJson != null) {
      writer.writeBool(true);
      writer.writeString(jsonEncode(obj.initialContextJson));
    } else {
      writer.writeBool(false);
    }
  }
}

// ============================================================================
// ADAPTATEURS POUR LE STREAMING (Janvier 2026)
// ============================================================================

/// Adaptateur Hive pour AdhaStreamType
///
/// TypeID: 104
class AdhaStreamTypeAdapter extends TypeAdapter<AdhaStreamType> {
  @override
  final int typeId = 104;

  @override
  AdhaStreamType read(BinaryReader reader) {
    return AdhaStreamType.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, AdhaStreamType obj) {
    writer.writeInt(obj.index);
  }
}

/// Adaptateur Hive pour AdhaStreamMetadata
///
/// TypeID: 105
class AdhaStreamMetadataAdapter extends TypeAdapter<AdhaStreamMetadata> {
  @override
  final int typeId = 105;

  @override
  AdhaStreamMetadata read(BinaryReader reader) {
    final numFields = reader.readByte();

    String source = 'unknown';
    String streamVersion = '1.0.0';
    bool? streamComplete;
    bool? error;

    for (int i = 0; i < numFields; i++) {
      final fieldId = reader.readByte();
      switch (fieldId) {
        case 0:
          source = reader.readString();
          break;
        case 1:
          streamVersion = reader.readString();
          break;
        case 2:
          final hasValue = reader.readBool();
          if (hasValue) streamComplete = reader.readBool();
          break;
        case 3:
          final hasValue = reader.readBool();
          if (hasValue) error = reader.readBool();
          break;
      }
    }

    return AdhaStreamMetadata(
      source: source,
      streamVersion: streamVersion,
      streamComplete: streamComplete,
      error: error,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaStreamMetadata obj) {
    writer.writeByte(4); // Nombre de champs

    writer.writeByte(0);
    writer.writeString(obj.source);

    writer.writeByte(1);
    writer.writeString(obj.streamVersion);

    writer.writeByte(2);
    writer.writeBool(obj.streamComplete != null);
    if (obj.streamComplete != null) writer.writeBool(obj.streamComplete!);

    writer.writeByte(3);
    writer.writeBool(obj.error != null);
    if (obj.error != null) writer.writeBool(obj.error!);
  }
}

/// Adaptateur Hive pour AdhaStreamChunkEvent
///
/// TypeID: 106
///
/// Utilisé pour le cache local des événements de streaming (optionnel)
class AdhaStreamChunkEventAdapter extends TypeAdapter<AdhaStreamChunkEvent> {
  @override
  final int typeId = 106;

  @override
  AdhaStreamChunkEvent read(BinaryReader reader) {
    final numFields = reader.readByte();

    String id = '';
    String requestMessageId = '';
    String conversationId = '';
    AdhaStreamType type = AdhaStreamType.chunk;
    String content = '';
    int chunkId = 0;
    DateTime timestamp = DateTime.now();
    String userId = '';
    String companyId = '';
    int? totalChunks;
    Map<String, dynamic>? processingDetails;
    AdhaStreamMetadata? metadata;

    for (int i = 0; i < numFields; i++) {
      final fieldId = reader.readByte();
      switch (fieldId) {
        case 0:
          id = reader.readString();
          break;
        case 1:
          requestMessageId = reader.readString();
          break;
        case 2:
          conversationId = reader.readString();
          break;
        case 3:
          type = AdhaStreamType.values[reader.readInt()];
          break;
        case 4:
          content = reader.readString();
          break;
        case 5:
          chunkId = reader.readInt();
          break;
        case 6:
          timestamp = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
          break;
        case 7:
          userId = reader.readString();
          break;
        case 8:
          companyId = reader.readString();
          break;
        case 9:
          final hasValue = reader.readBool();
          if (hasValue) totalChunks = reader.readInt();
          break;
        case 10:
          final hasValue = reader.readBool();
          if (hasValue) {
            final jsonStr = reader.readString();
            processingDetails = jsonDecode(jsonStr) as Map<String, dynamic>;
          }
          break;
        case 11:
          final hasValue = reader.readBool();
          if (hasValue) metadata = reader.read() as AdhaStreamMetadata;
          break;
      }
    }

    return AdhaStreamChunkEvent(
      id: id,
      requestMessageId: requestMessageId,
      conversationId: conversationId,
      type: type,
      content: content,
      chunkId: chunkId,
      timestamp: timestamp,
      userId: userId,
      companyId: companyId,
      totalChunks: totalChunks,
      processingDetails: processingDetails,
      metadata: metadata,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaStreamChunkEvent obj) {
    writer.writeByte(12); // Nombre de champs

    writer.writeByte(0);
    writer.writeString(obj.id);

    writer.writeByte(1);
    writer.writeString(obj.requestMessageId);

    writer.writeByte(2);
    writer.writeString(obj.conversationId);

    writer.writeByte(3);
    writer.writeInt(obj.type.index);

    writer.writeByte(4);
    writer.writeString(obj.content);

    writer.writeByte(5);
    writer.writeInt(obj.chunkId);

    writer.writeByte(6);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);

    writer.writeByte(7);
    writer.writeString(obj.userId);

    writer.writeByte(8);
    writer.writeString(obj.companyId);

    writer.writeByte(9);
    writer.writeBool(obj.totalChunks != null);
    if (obj.totalChunks != null) writer.writeInt(obj.totalChunks!);

    writer.writeByte(10);
    writer.writeBool(obj.processingDetails != null);
    if (obj.processingDetails != null) {
      writer.writeString(jsonEncode(obj.processingDetails));
    }

    writer.writeByte(11);
    writer.writeBool(obj.metadata != null);
    if (obj.metadata != null) writer.write(obj.metadata);
  }
}

// ============================================================================
// ADAPTATEURS POUR LE CONTEXTE (Janvier 2026)
// ============================================================================

/// Adaptateur Hive pour AdhaInteractionType
///
/// TypeID: 107
class AdhaInteractionTypeAdapter extends TypeAdapter<AdhaInteractionType> {
  @override
  final int typeId = 107;

  @override
  AdhaInteractionType read(BinaryReader reader) {
    return AdhaInteractionType.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, AdhaInteractionType obj) {
    writer.writeInt(obj.index);
  }
}

/// Adaptateur Hive pour AdhaOperationJournalEntry
///
/// TypeID: 108
class AdhaOperationJournalEntryAdapter
    extends TypeAdapter<AdhaOperationJournalEntry> {
  @override
  final int typeId = 108;

  @override
  AdhaOperationJournalEntry read(BinaryReader reader) {
    final numFields = reader.readByte();

    String timestamp = '';
    String description = '';
    String operationType = '';
    Map<String, dynamic>? details;

    for (int i = 0; i < numFields; i++) {
      final fieldId = reader.readByte();
      switch (fieldId) {
        case 0:
          timestamp = reader.readString();
          break;
        case 1:
          description = reader.readString();
          break;
        case 2:
          operationType = reader.readString();
          break;
        case 3:
          final hasValue = reader.readBool();
          if (hasValue) {
            final jsonStr = reader.readString();
            details = jsonDecode(jsonStr) as Map<String, dynamic>;
          }
          break;
      }
    }

    return AdhaOperationJournalEntry(
      timestamp: timestamp,
      description: description,
      operationType: operationType,
      details: details,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaOperationJournalEntry obj) {
    writer.writeByte(4);

    writer.writeByte(0);
    writer.writeString(obj.timestamp);

    writer.writeByte(1);
    writer.writeString(obj.description);

    writer.writeByte(2);
    writer.writeString(obj.operationType);

    writer.writeByte(3);
    writer.writeBool(obj.details != null);
    if (obj.details != null) {
      writer.writeString(jsonEncode(obj.details));
    }
  }
}

/// Adaptateur Hive pour AdhaBusinessProfile
///
/// TypeID: 109
class AdhaBusinessProfileAdapter extends TypeAdapter<AdhaBusinessProfile> {
  @override
  final int typeId = 109;

  @override
  AdhaBusinessProfile read(BinaryReader reader) {
    final numFields = reader.readByte();

    String name = '';
    String? sector;
    String? address;
    Map<String, dynamic>? additionalInfo;

    for (int i = 0; i < numFields; i++) {
      final fieldId = reader.readByte();
      switch (fieldId) {
        case 0:
          name = reader.readString();
          break;
        case 1:
          final hasValue = reader.readBool();
          if (hasValue) sector = reader.readString();
          break;
        case 2:
          final hasValue = reader.readBool();
          if (hasValue) address = reader.readString();
          break;
        case 3:
          final hasValue = reader.readBool();
          if (hasValue) {
            final jsonStr = reader.readString();
            additionalInfo = jsonDecode(jsonStr) as Map<String, dynamic>;
          }
          break;
      }
    }

    return AdhaBusinessProfile(
      name: name,
      sector: sector,
      address: address,
      additionalInfo: additionalInfo,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaBusinessProfile obj) {
    writer.writeByte(4);

    writer.writeByte(0);
    writer.writeString(obj.name);

    writer.writeByte(1);
    writer.writeBool(obj.sector != null);
    if (obj.sector != null) writer.writeString(obj.sector!);

    writer.writeByte(2);
    writer.writeBool(obj.address != null);
    if (obj.address != null) writer.writeString(obj.address!);

    writer.writeByte(3);
    writer.writeBool(obj.additionalInfo != null);
    if (obj.additionalInfo != null) {
      writer.writeString(jsonEncode(obj.additionalInfo));
    }
  }
}

// ============================================================================
// FONCTION D'ENREGISTREMENT GLOBAL
// ============================================================================

/// Enregistre tous les adaptateurs Hive pour le module ADHA
///
/// Cette fonction doit être appelée avant d'utiliser les boxes Hive ADHA.
/// Elle vérifie si chaque adaptateur est déjà enregistré avant de l'ajouter.
void registerAdhaHiveAdapters() {
  // Message adapters
  if (!Hive.isAdapterRegistered(100)) {
    Hive.registerAdapter(AdhaMessageAdapter());
  }
  if (!Hive.isAdapterRegistered(101)) {
    Hive.registerAdapter(AdhaMessageTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(102)) {
    Hive.registerAdapter(AdhaConversationAdapter());
  }
  if (!Hive.isAdapterRegistered(103)) {
    Hive.registerAdapter(AdhaMessageSenderAdapter());
  }

  // Stream adapters
  if (!Hive.isAdapterRegistered(104)) {
    Hive.registerAdapter(AdhaStreamTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(105)) {
    Hive.registerAdapter(AdhaStreamMetadataAdapter());
  }
  if (!Hive.isAdapterRegistered(106)) {
    Hive.registerAdapter(AdhaStreamChunkEventAdapter());
  }

  // Context adapters
  if (!Hive.isAdapterRegistered(107)) {
    Hive.registerAdapter(AdhaInteractionTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(108)) {
    Hive.registerAdapter(AdhaOperationJournalEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(109)) {
    Hive.registerAdapter(AdhaBusinessProfileAdapter());
  }
}
