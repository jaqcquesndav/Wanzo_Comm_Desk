// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 7;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sale(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      customerId: fields[2] as String?,
      customerName: fields[3] as String,
      items: (fields[4] as List).cast<SaleItem>(),
      totalAmountInCdf: fields[5] as double,
      paidAmountInCdf: fields[6] as double,
      paymentMethod: fields[7] as String?,
      status: fields[8] as SaleStatus,
      notes: fields[9] as String?,
      transactionCurrencyCode: fields[10] as String?,
      transactionExchangeRate: fields[11] as double?,
      totalAmountInTransactionCurrency: fields[12] as double?,
      paidAmountInTransactionCurrency: fields[13] as double?,
      discountPercentage: fields[14] as double,
      companyId: fields[15] as String?,
      businessUnitId: fields[16] as String?,
      businessUnitCode: fields[17] as String?,
      businessUnitType: fields[18] as BusinessUnitType?,
      attachmentUrls: (fields[19] as List?)?.cast<String>(),
      localAttachmentPaths: (fields[20] as List?)?.cast<String>(),
      paymentReference: fields[21] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.customerId)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.items)
      ..writeByte(5)
      ..write(obj.totalAmountInCdf)
      ..writeByte(6)
      ..write(obj.paidAmountInCdf)
      ..writeByte(7)
      ..write(obj.paymentMethod)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.transactionCurrencyCode)
      ..writeByte(11)
      ..write(obj.transactionExchangeRate)
      ..writeByte(12)
      ..write(obj.totalAmountInTransactionCurrency)
      ..writeByte(13)
      ..write(obj.paidAmountInTransactionCurrency)
      ..writeByte(14)
      ..write(obj.discountPercentage)
      ..writeByte(15)
      ..write(obj.companyId)
      ..writeByte(16)
      ..write(obj.businessUnitId)
      ..writeByte(17)
      ..write(obj.businessUnitCode)
      ..writeByte(18)
      ..write(obj.businessUnitType)
      ..writeByte(19)
      ..write(obj.attachmentUrls)
      ..writeByte(20)
      ..write(obj.localAttachmentPaths)
      ..writeByte(21)
      ..write(obj.paymentReference);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SaleStatusAdapter extends TypeAdapter<SaleStatus> {
  @override
  final int typeId = 6;

  @override
  SaleStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SaleStatus.pending;
      case 1:
        return SaleStatus.completed;
      case 2:
        return SaleStatus.cancelled;
      case 3:
        return SaleStatus.partiallyPaid;
      default:
        return SaleStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, SaleStatus obj) {
    switch (obj) {
      case SaleStatus.pending:
        writer.writeByte(0);
        break;
      case SaleStatus.completed:
        writer.writeByte(1);
        break;
      case SaleStatus.cancelled:
        writer.writeByte(2);
        break;
      case SaleStatus.partiallyPaid:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Sale _$SaleFromJson(Map<String, dynamic> json) => Sale(
      id: json['id'] as String,
      localId: json['localId'] as String?,
      date: DateTime.parse(json['date'] as String),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAmountInCdf: (json['totalAmountInCdf'] as num).toDouble(),
      paidAmountInCdf: (json['paidAmountInCdf'] as num?)?.toDouble() ?? 0.0,
      totalAmountInUsd: (json['totalAmountInUsd'] as num?)?.toDouble(),
      paidAmountInUsd: (json['paidAmountInUsd'] as num?)?.toDouble(),
      paymentMethod: json['paymentMethod'] as String?,
      status: $enumDecode(_$SaleStatusEnumMap, json['status']),
      invoiceNumber: json['invoiceNumber'] as String?,
      notes: json['notes'] as String? ?? '',
      transactionCurrencyCode: json['transactionCurrencyCode'] as String?,
      transactionExchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
      totalAmountInTransactionCurrency:
          (json['totalAmountInTransactionCurrency'] as num?)?.toDouble(),
      paidAmountInTransactionCurrency:
          (json['paidAmountInTransactionCurrency'] as num?)?.toDouble(),
      discountPercentage:
          (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType:
          Sale._businessUnitTypeFromJson(json['businessUnitType'] as String?),
      attachmentUrls: (json['attachmentUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      paymentReference: json['paymentReference'] as String?,
      userId: json['userId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$SaleToJson(Sale instance) => <String, dynamic>{
      'id': instance.id,
      if (instance.localId case final value?) 'localId': value,
      'date': instance.date.toIso8601String(),
      if (instance.dueDate?.toIso8601String() case final value?)
        'dueDate': value,
      if (instance.customerId case final value?) 'customerId': value,
      'customerName': instance.customerName,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'totalAmountInCdf': instance.totalAmountInCdf,
      'paidAmountInCdf': instance.paidAmountInCdf,
      if (instance.totalAmountInUsd case final value?)
        'totalAmountInUsd': value,
      if (instance.paidAmountInUsd case final value?) 'paidAmountInUsd': value,
      if (instance.paymentMethod case final value?) 'paymentMethod': value,
      'status': _$SaleStatusEnumMap[instance.status]!,
      if (instance.invoiceNumber case final value?) 'invoiceNumber': value,
      if (instance.notes case final value?) 'notes': value,
      if (instance.transactionCurrencyCode case final value?)
        'transactionCurrencyCode': value,
      if (instance.transactionExchangeRate case final value?)
        'exchangeRate': value,
      if (instance.totalAmountInTransactionCurrency case final value?)
        'totalAmountInTransactionCurrency': value,
      if (instance.paidAmountInTransactionCurrency case final value?)
        'paidAmountInTransactionCurrency': value,
      'discountPercentage': instance.discountPercentage,
      if (instance.companyId case final value?) 'companyId': value,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
      if (instance.businessUnitCode case final value?)
        'businessUnitCode': value,
      if (Sale._businessUnitTypeToJson(instance.businessUnitType)
          case final value?)
        'businessUnitType': value,
      if (instance.attachmentUrls case final value?) 'attachmentUrls': value,
      if (instance.paymentReference case final value?)
        'paymentReference': value,
      if (instance.userId case final value?) 'userId': value,
      if (instance.createdAt?.toIso8601String() case final value?)
        'createdAt': value,
      if (instance.updatedAt?.toIso8601String() case final value?)
        'updatedAt': value,
    };

const _$SaleStatusEnumMap = {
  SaleStatus.pending: 'pending',
  SaleStatus.completed: 'completed',
  SaleStatus.cancelled: 'cancelled',
  SaleStatus.partiallyPaid: 'partiallyPaid',
};
