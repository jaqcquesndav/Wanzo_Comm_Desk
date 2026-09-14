// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_contact.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomerContactAdapter extends TypeAdapter<CustomerContact> {
  @override
  final int typeId = 205;

  @override
  CustomerContact read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomerContact(
      name: fields[0] as String,
      role: fields[1] as String?,
      phone: fields[2] as String?,
      email: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CustomerContact obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerContactAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomerContact _$CustomerContactFromJson(Map<String, dynamic> json) =>
    CustomerContact(
      name: json['name'] as String,
      role: json['role'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$CustomerContactToJson(CustomerContact instance) =>
    <String, dynamic>{
      'name': instance.name,
      if (instance.role case final value?) 'role': value,
      if (instance.phone case final value?) 'phone': value,
      if (instance.email case final value?) 'email': value,
    };
