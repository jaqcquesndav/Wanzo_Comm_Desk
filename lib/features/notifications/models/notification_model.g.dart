// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotificationModelAdapter extends TypeAdapter<NotificationModel> {
  @override
  final int typeId = 28;

  @override
  NotificationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationModel(
      id: fields[0] as String,
      title: fields[1] as String?,
      message: fields[2] as String,
      type: fields[3] as NotificationType,
      timestamp: fields[4] as DateTime,
      isRead: fields[5] as bool,
      actionRoute: fields[6] as String?,
      additionalData: fields[7] as String?,
      companyId: fields[8] as String?,
      businessUnitId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.message)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.isRead)
      ..writeByte(6)
      ..write(obj.actionRoute)
      ..writeByte(7)
      ..write(obj.additionalData)
      ..writeByte(8)
      ..write(obj.companyId)
      ..writeByte(9)
      ..write(obj.businessUnitId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationTypeAdapter extends TypeAdapter<NotificationType> {
  @override
  final int typeId = 29;

  @override
  NotificationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NotificationType.info;
      case 1:
        return NotificationType.success;
      case 2:
        return NotificationType.warning;
      case 3:
        return NotificationType.error;
      case 4:
        return NotificationType.lowStock;
      case 5:
        return NotificationType.sale;
      case 6:
        return NotificationType.payment;
      default:
        return NotificationType.info;
    }
  }

  @override
  void write(BinaryWriter writer, NotificationType obj) {
    switch (obj) {
      case NotificationType.info:
        writer.writeByte(0);
        break;
      case NotificationType.success:
        writer.writeByte(1);
        break;
      case NotificationType.warning:
        writer.writeByte(2);
        break;
      case NotificationType.error:
        writer.writeByte(3);
        break;
      case NotificationType.lowStock:
        writer.writeByte(4);
        break;
      case NotificationType.sale:
        writer.writeByte(5);
        break;
      case NotificationType.payment:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String?,
      message: json['message'] as String,
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      actionRoute: json['actionRoute'] as String?,
      additionalData: json['additionalData'] as String?,
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
    );

Map<String, dynamic> _$NotificationModelToJson(NotificationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      if (instance.title case final value?) 'title': value,
      'message': instance.message,
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'isRead': instance.isRead,
      if (instance.actionRoute case final value?) 'actionRoute': value,
      if (instance.additionalData case final value?) 'additionalData': value,
      if (instance.companyId case final value?) 'companyId': value,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
    };

const _$NotificationTypeEnumMap = {
  NotificationType.info: 'info',
  NotificationType.success: 'success',
  NotificationType.warning: 'warning',
  NotificationType.error: 'error',
  NotificationType.lowStock: 'lowStock',
  NotificationType.sale: 'sale',
  NotificationType.payment: 'payment',
};
