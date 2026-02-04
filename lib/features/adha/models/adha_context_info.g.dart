// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adha_context_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdhaOperationJournalEntryAdapter
    extends TypeAdapter<AdhaOperationJournalEntry> {
  @override
  final int typeId = 108;

  @override
  AdhaOperationJournalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaOperationJournalEntry(
      timestamp: fields[0] as String,
      description: fields[1] as String,
      operationType: fields[2] as String,
      details: (fields[3] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, AdhaOperationJournalEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.operationType)
      ..writeByte(3)
      ..write(obj.details);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaOperationJournalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaOperationJournalSummaryAdapter
    extends TypeAdapter<AdhaOperationJournalSummary> {
  @override
  final int typeId = 110;

  @override
  AdhaOperationJournalSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaOperationJournalSummary(
      recentEntries: (fields[0] as List).cast<AdhaOperationJournalEntry>(),
    );
  }

  @override
  void write(BinaryWriter writer, AdhaOperationJournalSummary obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.recentEntries);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaOperationJournalSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaBusinessProfileAdapter extends TypeAdapter<AdhaBusinessProfile> {
  @override
  final int typeId = 109;

  @override
  AdhaBusinessProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaBusinessProfile(
      name: fields[0] as String,
      sector: fields[1] as String?,
      address: fields[2] as String?,
      additionalInfo: (fields[3] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, AdhaBusinessProfile obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.sector)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.additionalInfo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaBusinessProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaBaseContextAdapter extends TypeAdapter<AdhaBaseContext> {
  @override
  final int typeId = 111;

  @override
  AdhaBaseContext read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaBaseContext(
      operationJournalSummary: fields[0] as AdhaOperationJournalSummary,
      businessProfile: fields[1] as AdhaBusinessProfile,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaBaseContext obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.operationJournalSummary)
      ..writeByte(1)
      ..write(obj.businessProfile);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaBaseContextAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaInteractionContextAdapter
    extends TypeAdapter<AdhaInteractionContext> {
  @override
  final int typeId = 112;

  @override
  AdhaInteractionContext read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaInteractionContext(
      interactionType: fields[0] as AdhaInteractionType,
      sourceIdentifier: fields[1] as String?,
      interactionData: (fields[2] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, AdhaInteractionContext obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.interactionType)
      ..writeByte(1)
      ..write(obj.sourceIdentifier)
      ..writeByte(2)
      ..write(obj.interactionData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaInteractionContextAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaContextInfoAdapter extends TypeAdapter<AdhaContextInfo> {
  @override
  final int typeId = 113;

  @override
  AdhaContextInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdhaContextInfo(
      baseContext: fields[0] as AdhaBaseContext,
      interactionContext: fields[1] as AdhaInteractionContext,
    );
  }

  @override
  void write(BinaryWriter writer, AdhaContextInfo obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.baseContext)
      ..writeByte(1)
      ..write(obj.interactionContext);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaContextInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AdhaInteractionTypeAdapter extends TypeAdapter<AdhaInteractionType> {
  @override
  final int typeId = 107;

  @override
  AdhaInteractionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AdhaInteractionType.genericCardAnalysis;
      case 1:
        return AdhaInteractionType.followUp;
      default:
        return AdhaInteractionType.genericCardAnalysis;
    }
  }

  @override
  void write(BinaryWriter writer, AdhaInteractionType obj) {
    switch (obj) {
      case AdhaInteractionType.genericCardAnalysis:
        writer.writeByte(0);
        break;
      case AdhaInteractionType.followUp:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhaInteractionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
