// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_unit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BusinessUnitAdapter extends TypeAdapter<BusinessUnit> {
  @override
  final int typeId = 73;

  @override
  BusinessUnit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessUnit(
      id: fields[0] as String,
      code: fields[1] as String,
      name: fields[2] as String,
      type: fields[3] as BusinessUnitType,
      status: fields[4] as BusinessUnitStatus,
      companyId: fields[5] as String,
      parentId: fields[6] as String?,
      hierarchyLevel: fields[7] as int,
      hierarchyPath: fields[8] as String?,
      address: fields[9] as String?,
      city: fields[10] as String?,
      province: fields[11] as String?,
      country: fields[12] as String,
      phone: fields[13] as String?,
      email: fields[14] as String?,
      manager: fields[15] as String?,
      managerId: fields[16] as String?,
      currency: fields[17] as String,
      timezone: fields[18] as String,
      settings: (fields[19] as Map?)?.cast<String, dynamic>(),
      metadata: (fields[20] as Map?)?.cast<String, dynamic>(),
      accountingServiceId: fields[21] as String?,
      createdAt: fields[22] as DateTime,
      updatedAt: fields[23] as DateTime,
      createdBy: fields[24] as String?,
      updatedBy: fields[25] as String?,
      managerName: fields[26] as String?,
      scope: fields[27] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessUnit obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.code)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.companyId)
      ..writeByte(6)
      ..write(obj.parentId)
      ..writeByte(7)
      ..write(obj.hierarchyLevel)
      ..writeByte(8)
      ..write(obj.hierarchyPath)
      ..writeByte(9)
      ..write(obj.address)
      ..writeByte(10)
      ..write(obj.city)
      ..writeByte(11)
      ..write(obj.province)
      ..writeByte(12)
      ..write(obj.country)
      ..writeByte(13)
      ..write(obj.phone)
      ..writeByte(14)
      ..write(obj.email)
      ..writeByte(15)
      ..write(obj.manager)
      ..writeByte(16)
      ..write(obj.managerId)
      ..writeByte(17)
      ..write(obj.currency)
      ..writeByte(18)
      ..write(obj.timezone)
      ..writeByte(19)
      ..write(obj.settings)
      ..writeByte(20)
      ..write(obj.metadata)
      ..writeByte(21)
      ..write(obj.accountingServiceId)
      ..writeByte(22)
      ..write(obj.createdAt)
      ..writeByte(23)
      ..write(obj.updatedAt)
      ..writeByte(24)
      ..write(obj.createdBy)
      ..writeByte(25)
      ..write(obj.updatedBy)
      ..writeByte(26)
      ..write(obj.managerName)
      ..writeByte(27)
      ..write(obj.scope);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusinessUnit _$BusinessUnitFromJson(Map<String, dynamic> json) => BusinessUnit(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$BusinessUnitTypeEnumMap, json['type']),
      status:
          $enumDecodeNullable(_$BusinessUnitStatusEnumMap, json['status']) ??
              BusinessUnitStatus.active,
      companyId: json['companyId'] as String,
      parentId: json['parentId'] as String?,
      hierarchyLevel: (json['hierarchyLevel'] as num).toInt(),
      hierarchyPath: json['hierarchyPath'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      country: json['country'] as String? ?? 'RDC',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      manager: json['manager'] as String?,
      managerId: json['managerId'] as String?,
      currency: json['currency'] as String? ?? 'CDF',
      timezone: json['timezone'] as String? ?? 'Africa/Kinshasa',
      settings: json['settings'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      accountingServiceId: json['accountingServiceId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
      managerName: json['managerName'] as String?,
      scope: json['scope'] as String?,
    );

Map<String, dynamic> _$BusinessUnitToJson(BusinessUnit instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'name': instance.name,
      'type': _$BusinessUnitTypeEnumMap[instance.type]!,
      'status': _$BusinessUnitStatusEnumMap[instance.status]!,
      'companyId': instance.companyId,
      if (instance.parentId case final value?) 'parentId': value,
      'hierarchyLevel': instance.hierarchyLevel,
      if (instance.hierarchyPath case final value?) 'hierarchyPath': value,
      if (instance.address case final value?) 'address': value,
      if (instance.city case final value?) 'city': value,
      if (instance.province case final value?) 'province': value,
      'country': instance.country,
      if (instance.phone case final value?) 'phone': value,
      if (instance.email case final value?) 'email': value,
      if (instance.manager case final value?) 'manager': value,
      if (instance.managerId case final value?) 'managerId': value,
      'currency': instance.currency,
      'timezone': instance.timezone,
      if (instance.settings case final value?) 'settings': value,
      if (instance.metadata case final value?) 'metadata': value,
      if (instance.accountingServiceId case final value?)
        'accountingServiceId': value,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      if (instance.createdBy case final value?) 'createdBy': value,
      if (instance.updatedBy case final value?) 'updatedBy': value,
      if (instance.managerName case final value?) 'managerName': value,
      if (instance.scope case final value?) 'scope': value,
    };

const _$BusinessUnitTypeEnumMap = {
  BusinessUnitType.company: 'company',
  BusinessUnitType.branch: 'branch',
  BusinessUnitType.pos: 'pos',
};

const _$BusinessUnitStatusEnumMap = {
  BusinessUnitStatus.active: 'active',
  BusinessUnitStatus.inactive: 'inactive',
  BusinessUnitStatus.suspended: 'suspended',
  BusinessUnitStatus.closed: 'closed',
};

BusinessUnitHierarchy _$BusinessUnitHierarchyFromJson(
        Map<String, dynamic> json) =>
    BusinessUnitHierarchy(
      unit: BusinessUnit.fromJson(json['unit'] as Map<String, dynamic>),
      children: (json['children'] as List<dynamic>?)
              ?.map((e) =>
                  BusinessUnitHierarchy.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$BusinessUnitHierarchyToJson(
        BusinessUnitHierarchy instance) =>
    <String, dynamic>{
      'unit': instance.unit.toJson(),
      'children': instance.children.map((e) => e.toJson()).toList(),
    };

BusinessUnitSettings _$BusinessUnitSettingsFromJson(
        Map<String, dynamic> json) =>
    BusinessUnitSettings(
      defaultPriceList: json['defaultPriceList'] as String?,
      allowDiscounts: json['allowDiscounts'] as bool? ?? true,
      maxDiscountPercent:
          (json['maxDiscountPercent'] as num?)?.toDouble() ?? 15.0,
      maxTransactionAmount: (json['maxTransactionAmount'] as num?)?.toDouble(),
      dailyTransactionLimit:
          (json['dailyTransactionLimit'] as num?)?.toDouble(),
      defaultTaxRate: (json['defaultTaxRate'] as num?)?.toDouble() ?? 16.0,
      vatNumber: json['vatNumber'] as String?,
    );

Map<String, dynamic> _$BusinessUnitSettingsToJson(
        BusinessUnitSettings instance) =>
    <String, dynamic>{
      if (instance.defaultPriceList case final value?)
        'defaultPriceList': value,
      'allowDiscounts': instance.allowDiscounts,
      'maxDiscountPercent': instance.maxDiscountPercent,
      if (instance.maxTransactionAmount case final value?)
        'maxTransactionAmount': value,
      if (instance.dailyTransactionLimit case final value?)
        'dailyTransactionLimit': value,
      'defaultTaxRate': instance.defaultTaxRate,
      if (instance.vatNumber case final value?) 'vatNumber': value,
    };
