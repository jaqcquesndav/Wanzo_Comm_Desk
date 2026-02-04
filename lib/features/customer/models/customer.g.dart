// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 35;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer(
      id: fields[0] as String,
      name: fields[1] as String,
      phoneNumber: fields[2] as String,
      email: fields[3] as String?,
      address: fields[4] as String?,
      createdAt: fields[5] as DateTime,
      notes: fields[6] as String?,
      totalPurchases: fields[7] as double,
      lastPurchaseDate: fields[8] as DateTime?,
      category: fields[9] as CustomerCategory,
      profilePicture: fields[10] as String?,
      companyId: fields[11] as String?,
      businessUnitId: fields[12] as String?,
      businessUnitCode: fields[13] as String?,
      businessUnitType: fields[14] as BusinessUnitType?,
      updatedAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
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
      ..write(obj.lastPurchaseDate)
      ..writeByte(9)
      ..write(obj.category)
      ..writeByte(10)
      ..write(obj.profilePicture)
      ..writeByte(11)
      ..write(obj.companyId)
      ..writeByte(12)
      ..write(obj.businessUnitId)
      ..writeByte(13)
      ..write(obj.businessUnitCode)
      ..writeByte(14)
      ..write(obj.businessUnitType)
      ..writeByte(15)
      ..write(obj.updatedAt);
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

class CustomerCategoryAdapter extends TypeAdapter<CustomerCategory> {
  @override
  final int typeId = 36;

  @override
  CustomerCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CustomerCategory.vip;
      case 1:
        return CustomerCategory.regular;
      case 2:
        return CustomerCategory.new_customer;
      case 3:
        return CustomerCategory.occasional;
      case 4:
        return CustomerCategory.business;
      default:
        return CustomerCategory.vip;
    }
  }

  @override
  void write(BinaryWriter writer, CustomerCategory obj) {
    switch (obj) {
      case CustomerCategory.vip:
        writer.writeByte(0);
        break;
      case CustomerCategory.regular:
        writer.writeByte(1);
        break;
      case CustomerCategory.new_customer:
        writer.writeByte(2);
        break;
      case CustomerCategory.occasional:
        writer.writeByte(3);
        break;
      case CustomerCategory.business:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Customer _$CustomerFromJson(Map<String, dynamic> json) => Customer(
      id: json['id'] as String,
      name: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String?,
      address: json['address'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      notes: json['notes'] as String?,
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      lastPurchaseDate: json['lastPurchaseDate'] == null
          ? null
          : DateTime.parse(json['lastPurchaseDate'] as String),
      category:
          $enumDecodeNullable(_$CustomerCategoryEnumMap, json['category']) ??
              CustomerCategory.regular,
      profilePicture: json['profilePicture'] as String?,
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType: Customer._businessUnitTypeFromJson(
          json['businessUnitType'] as String?),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$CustomerToJson(Customer instance) => <String, dynamic>{
      'id': instance.id,
      'fullName': instance.name,
      'phoneNumber': instance.phoneNumber,
      if (instance.email case final value?) 'email': value,
      if (instance.address case final value?) 'address': value,
      'createdAt': instance.createdAt.toIso8601String(),
      if (instance.notes case final value?) 'notes': value,
      'totalPurchases': instance.totalPurchases,
      if (instance.lastPurchaseDate?.toIso8601String() case final value?)
        'lastPurchaseDate': value,
      'category': _$CustomerCategoryEnumMap[instance.category]!,
      if (instance.profilePicture case final value?) 'profilePicture': value,
      if (instance.companyId case final value?) 'companyId': value,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
      if (instance.businessUnitCode case final value?)
        'businessUnitCode': value,
      if (Customer._businessUnitTypeToJson(instance.businessUnitType)
          case final value?)
        'businessUnitType': value,
      if (instance.updatedAt?.toIso8601String() case final value?)
        'updatedAt': value,
    };

const _$CustomerCategoryEnumMap = {
  CustomerCategory.vip: 'vip',
  CustomerCategory.regular: 'regular',
  CustomerCategory.new_customer: 'new_customer',
  CustomerCategory.occasional: 'occasional',
  CustomerCategory.business: 'business',
};
