import 'package:hive/hive.dart';
import 'user.dart';

/// Adaptateur Hive pour la classe User
class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      phone: fields[3] as String,
      role: fields[4] as String,
      token: fields[5] as String,
      picture: fields[6] as String?,
      emailVerified: fields[20] as bool? ?? false, // New field with default value
      phoneVerified: fields[21] as bool? ?? false, // New field with default value
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.writeByte(22); // Updated from 7 to 22 to include all fields
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.email);
    writer.writeByte(3);
    writer.write(obj.phone);
    writer.writeByte(4);
    writer.write(obj.role);
    writer.writeByte(5);
    writer.write(obj.token);
    writer.writeByte(6);
    writer.write(obj.picture);
    // Add writing for new fields
    writer.writeByte(20);
    writer.write(obj.emailVerified);
    writer.writeByte(21);
    writer.write(obj.phoneVerified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
