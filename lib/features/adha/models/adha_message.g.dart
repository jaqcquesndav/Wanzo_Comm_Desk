// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adha_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdhaMessageAdapter extends TypeAdapter<AdhaMessage> {
  @override
  final int typeId = 100;

  @override
  AdhaMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaMessage(
      id: fields[0] as String,
      content: fields[1] as String,
      timestamp: fields[2] as DateTime,
      sender: fields[3] as AdhaMessageSender,
      type: fields[4] as AdhaMessageType,
      contextInfo: (fields[5] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, AdhaMessage obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.sender)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.contextInfo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaConversationAdapter extends TypeAdapter<AdhaConversation> {
  @override
  final int typeId = 102;

  @override
  AdhaConversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaConversation(
      id: fields[0] as String,
      title: fields[1] as String,
      createdAt: fields[2] as DateTime,
      updatedAt: fields[3] as DateTime,
      messages: (fields[4] as List).cast<AdhaMessage>(),
      initialContextJson: (fields[5] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, AdhaConversation obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.messages)
      ..writeByte(5)
      ..write(obj.initialContextJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaConversationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaMessageSenderAdapter extends TypeAdapter<AdhaMessageSender> {
  @override
  final int typeId = 103;

  @override
  AdhaMessageSender read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AdhaMessageSender.user;
      case 1:
        return AdhaMessageSender.ai;
      default:
        return AdhaMessageSender.user;
    }
  }

  @override
  void write(BinaryWriter writer, AdhaMessageSender obj) {
    switch (obj) {
      case AdhaMessageSender.user:
        writer.writeByte(0);
        break;
      case AdhaMessageSender.ai:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaMessageSenderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaMessageTypeAdapter extends TypeAdapter<AdhaMessageType> {
  @override
  final int typeId = 101;

  @override
  AdhaMessageType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AdhaMessageType.text;
      case 1:
        return AdhaMessageType.latex;
      case 2:
        return AdhaMessageType.graph;
      case 3:
        return AdhaMessageType.code;
      case 4:
        return AdhaMessageType.media;
      default:
        return AdhaMessageType.text;
    }
  }

  @override
  void write(BinaryWriter writer, AdhaMessageType obj) {
    switch (obj) {
      case AdhaMessageType.text:
        writer.writeByte(0);
        break;
      case AdhaMessageType.latex:
        writer.writeByte(1);
        break;
      case AdhaMessageType.graph:
        writer.writeByte(2);
        break;
      case AdhaMessageType.code:
        writer.writeByte(3);
        break;
      case AdhaMessageType.media:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaMessageTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
