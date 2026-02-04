// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 42;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer(
      id: fields[0] as String,
      fullName: fields[1] as String,
      phoneNumber: fields[2] as String,
      email: fields[3] as String?,
      address: fields[4] as String?,
      createdAt: fields[5] as DateTime,
      notes: fields[6] as String?,
      totalPurchases: fields[7] as double?,
      profilePicture: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.phoneNumber)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.address)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.totalPurchases)
      ..writeByte(8)
      ..write(obj.profilePicture);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Customer _$CustomerFromJson(Map<String, dynamic> json) => Customer(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String?,
      address: json['address'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      notes: json['notes'] as String?,
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble(),
      profilePicture: json['profilePicture'] as String?,
    );

Map<String, dynamic> _$CustomerToJson(Customer instance) => <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'phoneNumber': instance.phoneNumber,
      if (instance.email case final value?) 'email': value,
      if (instance.address case final value?) 'address': value,
      'createdAt': instance.createdAt.toIso8601String(),
      if (instance.notes case final value?) 'notes': value,
      if (instance.totalPurchases case final value?) 'totalPurchases': value,
      if (instance.profilePicture case final value?) 'profilePicture': value,
    };
