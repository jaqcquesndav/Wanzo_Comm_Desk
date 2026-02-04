import 'package:hive/hive.dart';
import 'user.dart'; // Assuming User and IdStatus are in user.dart

class UserAdapterV2 extends TypeAdapter<User> {
  @override
  final int typeId = 0; // Must be the same as the original UserAdapter typeId

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };    return User(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      phone: fields[3] as String,
      role: fields[4] as String,
      token: fields[5] as String,
      picture: fields[6] as String?,
      jobTitle: fields[7] as String?,
      physicalAddress: fields[8] as String?,
      idCard: fields[9] as String?,
      // Migration logic: If field 10 is null, default to IdStatus.UNKNOWN
      idCardStatus: fields[10] == null ? IdStatus.UNKNOWN : fields[10] as IdStatus,
      idCardStatusReason: fields[11] as String?,
      emailVerified: fields[20] as bool? ?? false,  // Added required field with default value
      phoneVerified: fields[21] as bool? ?? false,  // Added required field with default value
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    // This write logic should be identical to the one in the generated user.g.dart
    // It ensures that when data is re-saved during migration, it's in the correct new format.
    writer
      ..writeByte(12) // Total number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.role)
      ..writeByte(5)
      ..write(obj.token)
      ..writeByte(6)
      ..write(obj.picture)
      ..writeByte(7)
      ..write(obj.jobTitle)
      ..writeByte(8)
      ..write(obj.physicalAddress)
      ..writeByte(9)
      ..write(obj.idCard)
      ..writeByte(10)
      ..write(obj.idCardStatus) // Writes the non-null IdStatus
      ..writeByte(11)
      ..write(obj.idCardStatusReason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapterV2 &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
