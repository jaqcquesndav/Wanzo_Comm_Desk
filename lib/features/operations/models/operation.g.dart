// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OperationAdapter extends TypeAdapter<Operation> {
  @override
  final int typeId = 61;

  @override
  Operation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Operation(
      id: fields[0] as String,
      type: fields[1] as OperationType,
      date: fields[2] as DateTime,
      description: fields[3] as String,
      entityId: fields[4] as String?,
      amountCdf: fields[5] as double,
      amountUsd: fields[6] as double?,
      relatedPartyId: fields[7] as String?,
      relatedPartyName: fields[8] as String?,
      status: fields[9] as OperationStatus,
      createdBy: fields[10] as String?,
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      paymentMethod: fields[13] as String?,
      categoryId: fields[14] as String?,
      productCount: fields[15] as int?,
      notes: fields[16] as String?,
      companyId: fields[17] as String?,
      businessUnitId: fields[18] as String?,
      businessUnitCode: fields[19] as String?,
      businessUnitType: fields[20] as BusinessUnitType?,
      additionalData: (fields[21] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Operation obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.entityId)
      ..writeByte(5)
      ..write(obj.amountCdf)
      ..writeByte(6)
      ..write(obj.amountUsd)
      ..writeByte(7)
      ..write(obj.relatedPartyId)
      ..writeByte(8)
      ..write(obj.relatedPartyName)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.createdBy)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.paymentMethod)
      ..writeByte(14)
      ..write(obj.categoryId)
      ..writeByte(15)
      ..write(obj.productCount)
      ..writeByte(16)
      ..write(obj.notes)
      ..writeByte(17)
      ..write(obj.companyId)
      ..writeByte(18)
      ..write(obj.businessUnitId)
      ..writeByte(19)
      ..write(obj.businessUnitCode)
      ..writeByte(20)
      ..write(obj.businessUnitType)
      ..writeByte(21)
      ..write(obj.additionalData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OperationTypeAdapter extends TypeAdapter<OperationType> {
  @override
  final int typeId = 60;

  @override
  OperationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OperationType.sale;
      case 1:
        return OperationType.expense;
      case 2:
        return OperationType.financing;
      case 3:
        return OperationType.inventory;
      case 4:
        return OperationType.transaction;
      default:
        return OperationType.sale;
    }
  }

  @override
  void write(BinaryWriter writer, OperationType obj) {
    switch (obj) {
      case OperationType.sale:
        writer.writeByte(0);
        break;
      case OperationType.expense:
        writer.writeByte(1);
        break;
      case OperationType.financing:
        writer.writeByte(2);
        break;
      case OperationType.inventory:
        writer.writeByte(3);
        break;
      case OperationType.transaction:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OperationStatusAdapter extends TypeAdapter<OperationStatus> {
  @override
  final int typeId = 62;

  @override
  OperationStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OperationStatus.completed;
      case 1:
        return OperationStatus.pending;
      case 2:
        return OperationStatus.cancelled;
      case 3:
        return OperationStatus.failed;
      default:
        return OperationStatus.completed;
    }
  }

  @override
  void write(BinaryWriter writer, OperationStatus obj) {
    switch (obj) {
      case OperationStatus.completed:
        writer.writeByte(0);
        break;
      case OperationStatus.pending:
        writer.writeByte(1);
        break;
      case OperationStatus.cancelled:
        writer.writeByte(2);
        break;
      case OperationStatus.failed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Operation _$OperationFromJson(Map<String, dynamic> json) => Operation(
      id: json['id'] as String,
      type: $enumDecode(_$OperationTypeEnumMap, json['type']),
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String,
      entityId: json['entityId'] as String?,
      amountCdf: (json['amountCdf'] as num).toDouble(),
      amountUsd: (json['amountUsd'] as num?)?.toDouble(),
      relatedPartyId: json['relatedPartyId'] as String?,
      relatedPartyName: json['relatedPartyName'] as String?,
      status: Operation._statusFromJson(json['status']),
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      paymentMethod: json['paymentMethod'] as String?,
      categoryId: json['categoryId'] as String?,
      productCount: (json['productCount'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType: Operation._businessUnitTypeFromJson(
          json['businessUnitType'] as String?),
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$OperationToJson(Operation instance) => <String, dynamic>{
      'id': instance.id,
      'type': _$OperationTypeEnumMap[instance.type]!,
      'date': instance.date.toIso8601String(),
      'description': instance.description,
      if (instance.entityId case final value?) 'entityId': value,
      'amountCdf': instance.amountCdf,
      if (instance.amountUsd case final value?) 'amountUsd': value,
      if (instance.relatedPartyId case final value?) 'relatedPartyId': value,
      if (instance.relatedPartyName case final value?)
        'relatedPartyName': value,
      'status': Operation._statusToJson(instance.status),
      if (instance.createdBy case final value?) 'createdBy': value,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      if (instance.paymentMethod case final value?) 'paymentMethod': value,
      if (instance.categoryId case final value?) 'categoryId': value,
      if (instance.productCount case final value?) 'productCount': value,
      if (instance.notes case final value?) 'notes': value,
      if (instance.companyId case final value?) 'companyId': value,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
      if (instance.businessUnitCode case final value?)
        'businessUnitCode': value,
      if (Operation._businessUnitTypeToJson(instance.businessUnitType)
          case final value?)
        'businessUnitType': value,
      if (instance.additionalData case final value?) 'additionalData': value,
    };

const _$OperationTypeEnumMap = {
  OperationType.sale: 'sale',
  OperationType.expense: 'expense',
  OperationType.financing: 'financing',
  OperationType.inventory: 'inventory',
  OperationType.transaction: 'transaction',
};
