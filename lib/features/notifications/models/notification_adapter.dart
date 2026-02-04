// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\models\notification_adapter.dart
import 'package:hive/hive.dart';
import 'notification_model.dart';

/// Adaptateur Hive pour la classe NotificationModel
class NotificationModelAdapter extends TypeAdapter<NotificationModel> {
  @override
  final int typeId = 9;

  @override
  NotificationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
      return NotificationModel(
      id: fields[0] as String,
      title: fields[1] as String,
      message: fields[2] as String,
      type: fields[3] as NotificationType,
      timestamp: fields[4] as DateTime,
      isRead: fields[5] as bool? ?? false,
      actionRoute: fields[6] as String?,
      additionalData: fields[7] as String?,
    );
  }

  @override  void write(BinaryWriter writer, NotificationModel obj) {
    writer.writeByte(8);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.message);
    writer.writeByte(3);
    writer.write(obj.type);    writer.writeByte(4);
    writer.write(obj.timestamp);    writer.writeByte(5);
    writer.write(obj.isRead);
    writer.writeByte(6);
    writer.write(obj.actionRoute);    writer.writeByte(7);
    writer.write(obj.additionalData);    // imageUrl field was removed from the model
    // Keeping the same number of fields for compatibility
    writer.writeByte(8);
    writer.write(null);
  }
}

/// Adaptateur Hive pour la classe NotificationType
class NotificationTypeAdapter extends TypeAdapter<NotificationType> {
  @override
  final int typeId = 10;

  @override
  NotificationType read(BinaryReader reader) {
    return NotificationType.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, NotificationType obj) {
    writer.writeInt(obj.index);
  }
}
