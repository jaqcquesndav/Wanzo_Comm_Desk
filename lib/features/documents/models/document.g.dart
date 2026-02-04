// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocumentAdapter extends TypeAdapter<Document> {
  @override
  final int typeId = 31;

  @override
  Document read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Document(
      id: fields[0] as String,
      title: fields[1] as String,
      type: fields[2] as DocumentType,
      creationDate: fields[3] as DateTime,
      filePath: fields[4] as String,
      relatedEntityId: fields[5] as String?,
      relatedEntityType: fields[6] as String?,
      description: fields[7] as String?,
      fileSize: fields[8] as int?,
      fileType: fields[9] as String?,
      userId: fields[10] as String?,
      fileName: fields[11] as String?,
      fileUrl: fields[12] as String?,
      updatedAt: fields[13] as DateTime?,
      companyId: fields[14] as String?,
      businessUnitId: fields[15] as String?,
      businessUnitCode: fields[16] as String?,
      businessUnitType: fields[17] as BusinessUnitType?,
    );
  }

  @override
  void write(BinaryWriter writer, Document obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.creationDate)
      ..writeByte(4)
      ..write(obj.filePath)
      ..writeByte(5)
      ..write(obj.relatedEntityId)
      ..writeByte(6)
      ..write(obj.relatedEntityType)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.fileSize)
      ..writeByte(9)
      ..write(obj.fileType)
      ..writeByte(10)
      ..write(obj.userId)
      ..writeByte(11)
      ..write(obj.fileName)
      ..writeByte(12)
      ..write(obj.fileUrl)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.companyId)
      ..writeByte(15)
      ..write(obj.businessUnitId)
      ..writeByte(16)
      ..write(obj.businessUnitCode)
      ..writeByte(17)
      ..write(obj.businessUnitType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
