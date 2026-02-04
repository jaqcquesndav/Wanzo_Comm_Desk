// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StockTransactionAdapter extends TypeAdapter<StockTransaction> {
  @override
  final int typeId = 33;

  @override
  StockTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StockTransaction(
      id: fields[0] as String,
      productId: fields[1] as String,
      type: fields[2] as StockTransactionType,
      quantity: fields[3] as double,
      date: fields[4] as DateTime,
      referenceId: fields[5] as String?,
      notes: fields[6] as String?,
      unitCostInCdf: fields[7] as double,
      totalValueInCdf: fields[8] as double,
      currencyCode: fields[9] as String?,
      createdBy: fields[10] as String?,
      locationId: fields[11] as String?,
      companyId: fields[12] as String?,
      businessUnitId: fields[13] as String?,
      businessUnitCode: fields[14] as String?,
      businessUnitType: fields[15] as BusinessUnitType?,
    );
  }

  @override
  void write(BinaryWriter writer, StockTransaction obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.referenceId)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.unitCostInCdf)
      ..writeByte(8)
      ..write(obj.totalValueInCdf)
      ..writeByte(9)
      ..write(obj.currencyCode)
      ..writeByte(10)
      ..write(obj.createdBy)
      ..writeByte(11)
      ..write(obj.locationId)
      ..writeByte(12)
      ..write(obj.companyId)
      ..writeByte(13)
      ..write(obj.businessUnitId)
      ..writeByte(14)
      ..write(obj.businessUnitCode)
      ..writeByte(15)
      ..write(obj.businessUnitType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StockTransactionTypeAdapter extends TypeAdapter<StockTransactionType> {
  @override
  final int typeId = 32;

  @override
  StockTransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StockTransactionType.purchase;
      case 1:
        return StockTransactionType.sale;
      case 2:
        return StockTransactionType.adjustment;
      case 3:
        return StockTransactionType.transferIn;
      case 4:
        return StockTransactionType.transferOut;
      case 5:
        return StockTransactionType.returned;
      case 6:
        return StockTransactionType.damaged;
      case 7:
        return StockTransactionType.lost;
      case 8:
        return StockTransactionType.initialStock;
      default:
        return StockTransactionType.purchase;
    }
  }

  @override
  void write(BinaryWriter writer, StockTransactionType obj) {
    switch (obj) {
      case StockTransactionType.purchase:
        writer.writeByte(0);
        break;
      case StockTransactionType.sale:
        writer.writeByte(1);
        break;
      case StockTransactionType.adjustment:
        writer.writeByte(2);
        break;
      case StockTransactionType.transferIn:
        writer.writeByte(3);
        break;
      case StockTransactionType.transferOut:
        writer.writeByte(4);
        break;
      case StockTransactionType.returned:
        writer.writeByte(5);
        break;
      case StockTransactionType.damaged:
        writer.writeByte(6);
        break;
      case StockTransactionType.lost:
        writer.writeByte(7);
        break;
      case StockTransactionType.initialStock:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockTransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StockTransaction _$StockTransactionFromJson(Map<String, dynamic> json) =>
    StockTransaction(
      id: json['id'] as String,
      productId: json['productId'] as String,
      type: $enumDecode(_$StockTransactionTypeEnumMap, json['type']),
      quantity: (json['quantity'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      referenceId: json['referenceId'] as String?,
      notes: json['notes'] as String?,
      unitCostInCdf: (json['unitCostInCdf'] as num).toDouble(),
      totalValueInCdf: (json['totalValueInCdf'] as num).toDouble(),
      currencyCode: json['currencyCode'] as String?,
      createdBy: json['createdBy'] as String?,
      locationId: json['locationId'] as String?,
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType: $enumDecodeNullable(
          _$BusinessUnitTypeEnumMap, json['businessUnitType']),
    );

Map<String, dynamic> _$StockTransactionToJson(StockTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'productId': instance.productId,
      'type': _$StockTransactionTypeEnumMap[instance.type]!,
      'quantity': instance.quantity,
      'date': instance.date.toIso8601String(),
      if (instance.referenceId case final value?) 'referenceId': value,
      if (instance.notes case final value?) 'notes': value,
      'unitCostInCdf': instance.unitCostInCdf,
      'totalValueInCdf': instance.totalValueInCdf,
      if (instance.currencyCode case final value?) 'currencyCode': value,
      if (instance.createdBy case final value?) 'createdBy': value,
      if (instance.locationId case final value?) 'locationId': value,
      if (instance.companyId case final value?) 'companyId': value,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
      if (instance.businessUnitCode case final value?)
        'businessUnitCode': value,
      if (_$BusinessUnitTypeEnumMap[instance.businessUnitType]
          case final value?)
        'businessUnitType': value,
    };

const _$StockTransactionTypeEnumMap = {
  StockTransactionType.purchase: 'purchase',
  StockTransactionType.sale: 'sale',
  StockTransactionType.adjustment: 'adjustment',
  StockTransactionType.transferIn: 'transferIn',
  StockTransactionType.transferOut: 'transferOut',
  StockTransactionType.returned: 'returned',
  StockTransactionType.damaged: 'damaged',
  StockTransactionType.lost: 'lost',
  StockTransactionType.initialStock: 'initialStock',
};

const _$BusinessUnitTypeEnumMap = {
  BusinessUnitType.company: 'company',
  BusinessUnitType.branch: 'branch',
  BusinessUnitType.pos: 'pos',
};
