// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adha_stream_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdhaSuggestedActionAdapter extends TypeAdapter<AdhaSuggestedAction> {
  @override
  final int typeId = 107;

  @override
  AdhaSuggestedAction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaSuggestedAction(
      type: fields[0] as String,
      label: fields[1] as String?,
      payload: fields[2] as dynamic,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaSuggestedAction obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.payload);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaSuggestedActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaStreamMetadataAdapter extends TypeAdapter<AdhaStreamMetadata> {
  @override
  final int typeId = 105;

  @override
  AdhaStreamMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaStreamMetadata(
      source: fields[0] as String,
      streamVersion: fields[1] as String,
      streamComplete: fields[2] as bool?,
      error: fields[3] as bool?,
      errorType: fields[4] as String?,
      subscriptionRenewalUrl: fields[5] as String?,
      requiresAction: fields[6] as bool?,
      upgradeRequired: fields[7] as bool?,
      feature: fields[8] as String?,
      currentUsage: fields[9] as int?,
      limit: fields[10] as int?,
      gracePeriodDaysRemaining: fields[11] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaStreamMetadata obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.source)
      ..writeByte(1)
      ..write(obj.streamVersion)
      ..writeByte(2)
      ..write(obj.streamComplete)
      ..writeByte(3)
      ..write(obj.error)
      ..writeByte(4)
      ..write(obj.errorType)
      ..writeByte(5)
      ..write(obj.subscriptionRenewalUrl)
      ..writeByte(6)
      ..write(obj.requiresAction)
      ..writeByte(7)
      ..write(obj.upgradeRequired)
      ..writeByte(8)
      ..write(obj.feature)
      ..writeByte(9)
      ..write(obj.currentUsage)
      ..writeByte(10)
      ..write(obj.limit)
      ..writeByte(11)
      ..write(obj.gracePeriodDaysRemaining);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaStreamMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaStreamChunkEventAdapter extends TypeAdapter<AdhaStreamChunkEvent> {
  @override
  final int typeId = 106;

  @override
  AdhaStreamChunkEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaStreamChunkEvent(
      id: fields[0] as String,
      requestMessageId: fields[1] as String,
      conversationId: fields[2] as String,
      type: fields[3] as AdhaStreamType,
      content: fields[4] as String,
      chunkId: fields[5] as int,
      timestamp: fields[6] as DateTime,
      userId: fields[7] as String,
      companyId: fields[8] as String,
      totalChunks: fields[9] as int?,
      processingDetails: (fields[10] as Map?)?.cast<String, dynamic>(),
      metadata: fields[11] as AdhaStreamMetadata?,
      suggestedActions: (fields[12] as List?)?.cast<AdhaSuggestedAction>(),
    );
  }

  @override
  void write(BinaryWriter writer, AdhaStreamChunkEvent obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.requestMessageId)
      ..writeByte(2)
      ..write(obj.conversationId)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.chunkId)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.userId)
      ..writeByte(8)
      ..write(obj.companyId)
      ..writeByte(9)
      ..write(obj.totalChunks)
      ..writeByte(10)
      ..write(obj.processingDetails)
      ..writeByte(11)
      ..write(obj.metadata)
      ..writeByte(12)
      ..write(obj.suggestedActions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaStreamChunkEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaStreamTypeAdapter extends TypeAdapter<AdhaStreamType> {
  @override
  final int typeId = 104;

  @override
  AdhaStreamType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AdhaStreamType.chunk;
      case 1:
        return AdhaStreamType.end;
      case 2:
        return AdhaStreamType.error;
      case 3:
        return AdhaStreamType.toolCall;
      case 4:
        return AdhaStreamType.toolResult;
      case 5:
        return AdhaStreamType.cancelled;
      case 6:
        return AdhaStreamType.heartbeat;
      default:
        return AdhaStreamType.chunk;
    }
  }

  @override
  void write(BinaryWriter writer, AdhaStreamType obj) {
    switch (obj) {
      case AdhaStreamType.chunk:
        writer.writeByte(0);
        break;
      case AdhaStreamType.end:
        writer.writeByte(1);
        break;
      case AdhaStreamType.error:
        writer.writeByte(2);
        break;
      case AdhaStreamType.toolCall:
        writer.writeByte(3);
        break;
      case AdhaStreamType.toolResult:
        writer.writeByte(4);
        break;
      case AdhaStreamType.cancelled:
        writer.writeByte(5);
        break;
      case AdhaStreamType.heartbeat:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaStreamTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
