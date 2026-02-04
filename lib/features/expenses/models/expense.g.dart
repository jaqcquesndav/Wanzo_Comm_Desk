// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final int typeId = 11;

  @override
  Expense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Expense(
      id: fields[0] as String,
      localId: fields[9] as String?,
      date: fields[1] as DateTime,
      motif: fields[2] as String,
      amount: fields[3] as double,
      category: fields[4] as ExpenseCategory,
      paymentMethod: fields[5] as String?,
      attachmentUrls: (fields[6] as List?)?.cast<String>(),
      localAttachmentPaths: (fields[10] as List?)?.cast<String>(),
      supplierId: fields[7] as String?,
      beneficiary: fields[11] as String?,
      notes: fields[12] as String?,
      currencyCode: fields[8] as String?,
      supplierName: fields[13] as String?,
      paidAmount: fields[14] as double?,
      exchangeRate: fields[15] as double?,
      paymentStatus: fields[16] as ExpensePaymentStatus?,
      companyId: fields[17] as String?,
      businessUnitId: fields[18] as String?,
      businessUnitCode: fields[19] as String?,
      businessUnitType: fields[20] as BusinessUnitType?,
    );
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(9)
      ..write(obj.localId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.motif)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.paymentMethod)
      ..writeByte(6)
      ..write(obj.attachmentUrls)
      ..writeByte(10)
      ..write(obj.localAttachmentPaths)
      ..writeByte(7)
      ..write(obj.supplierId)
      ..writeByte(11)
      ..write(obj.beneficiary)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.currencyCode)
      ..writeByte(13)
      ..write(obj.supplierName)
      ..writeByte(14)
      ..write(obj.paidAmount)
      ..writeByte(15)
      ..write(obj.exchangeRate)
      ..writeByte(16)
      ..write(obj.paymentStatus)
      ..writeByte(17)
      ..write(obj.companyId)
      ..writeByte(18)
      ..write(obj.businessUnitId)
      ..writeByte(19)
      ..write(obj.businessUnitCode)
      ..writeByte(20)
      ..write(obj.businessUnitType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExpenseCategoryAdapter extends TypeAdapter<ExpenseCategory> {
  @override
  final int typeId = 202;

  @override
  ExpenseCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExpenseCategory.rent;
      case 1:
        return ExpenseCategory.utilities;
      case 2:
        return ExpenseCategory.supplies;
      case 3:
        return ExpenseCategory.salaries;
      case 4:
        return ExpenseCategory.marketing;
      case 5:
        return ExpenseCategory.transport;
      case 6:
        return ExpenseCategory.maintenance;
      case 7:
        return ExpenseCategory.other;
      case 8:
        return ExpenseCategory.inventory;
      case 9:
        return ExpenseCategory.equipment;
      case 10:
        return ExpenseCategory.taxes;
      case 11:
        return ExpenseCategory.insurance;
      case 12:
        return ExpenseCategory.loan;
      case 13:
        return ExpenseCategory.office;
      case 14:
        return ExpenseCategory.training;
      case 15:
        return ExpenseCategory.travel;
      case 16:
        return ExpenseCategory.software;
      case 17:
        return ExpenseCategory.advertising;
      case 18:
        return ExpenseCategory.legal;
      case 19:
        return ExpenseCategory.manufacturing;
      case 20:
        return ExpenseCategory.consulting;
      case 21:
        return ExpenseCategory.research;
      case 22:
        return ExpenseCategory.fuel;
      case 23:
        return ExpenseCategory.entertainment;
      case 24:
        return ExpenseCategory.communication;
      default:
        return ExpenseCategory.rent;
    }
  }

  @override
  void write(BinaryWriter writer, ExpenseCategory obj) {
    switch (obj) {
      case ExpenseCategory.rent:
        writer.writeByte(0);
        break;
      case ExpenseCategory.utilities:
        writer.writeByte(1);
        break;
      case ExpenseCategory.supplies:
        writer.writeByte(2);
        break;
      case ExpenseCategory.salaries:
        writer.writeByte(3);
        break;
      case ExpenseCategory.marketing:
        writer.writeByte(4);
        break;
      case ExpenseCategory.transport:
        writer.writeByte(5);
        break;
      case ExpenseCategory.maintenance:
        writer.writeByte(6);
        break;
      case ExpenseCategory.other:
        writer.writeByte(7);
        break;
      case ExpenseCategory.inventory:
        writer.writeByte(8);
        break;
      case ExpenseCategory.equipment:
        writer.writeByte(9);
        break;
      case ExpenseCategory.taxes:
        writer.writeByte(10);
        break;
      case ExpenseCategory.insurance:
        writer.writeByte(11);
        break;
      case ExpenseCategory.loan:
        writer.writeByte(12);
        break;
      case ExpenseCategory.office:
        writer.writeByte(13);
        break;
      case ExpenseCategory.training:
        writer.writeByte(14);
        break;
      case ExpenseCategory.travel:
        writer.writeByte(15);
        break;
      case ExpenseCategory.software:
        writer.writeByte(16);
        break;
      case ExpenseCategory.advertising:
        writer.writeByte(17);
        break;
      case ExpenseCategory.legal:
        writer.writeByte(18);
        break;
      case ExpenseCategory.manufacturing:
        writer.writeByte(19);
        break;
      case ExpenseCategory.consulting:
        writer.writeByte(20);
        break;
      case ExpenseCategory.research:
        writer.writeByte(21);
        break;
      case ExpenseCategory.fuel:
        writer.writeByte(22);
        break;
      case ExpenseCategory.entertainment:
        writer.writeByte(23);
        break;
      case ExpenseCategory.communication:
        writer.writeByte(24);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExpensePaymentStatusAdapter extends TypeAdapter<ExpensePaymentStatus> {
  @override
  final int typeId = 203;

  @override
  ExpensePaymentStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExpensePaymentStatus.paid;
      case 1:
        return ExpensePaymentStatus.partial;
      case 2:
        return ExpensePaymentStatus.unpaid;
      case 3:
        return ExpensePaymentStatus.credit;
      default:
        return ExpensePaymentStatus.paid;
    }
  }

  @override
  void write(BinaryWriter writer, ExpensePaymentStatus obj) {
    switch (obj) {
      case ExpensePaymentStatus.paid:
        writer.writeByte(0);
        break;
      case ExpensePaymentStatus.partial:
        writer.writeByte(1);
        break;
      case ExpensePaymentStatus.unpaid:
        writer.writeByte(2);
        break;
      case ExpensePaymentStatus.credit:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpensePaymentStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Expense _$ExpenseFromJson(Map<String, dynamic> json) => Expense(
      id: json['id'] as String,
      localId: json['localId'] as String?,
      date: DateTime.parse(json['date'] as String),
      motif: json['motif'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: $enumDecode(_$ExpenseCategoryEnumMap, json['category']),
      paymentMethod: json['paymentMethod'] as String?,
      attachmentUrls: (json['attachmentUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      supplierId: json['supplierId'] as String?,
      beneficiary: json['beneficiary'] as String?,
      notes: json['notes'] as String?,
      currencyCode: json['currencyCode'] as String?,
      supplierName: json['supplierName'] as String?,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
      paymentStatus: $enumDecodeNullable(
              _$ExpensePaymentStatusEnumMap, json['paymentStatus']) ??
          ExpensePaymentStatus.unpaid,
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType: $enumDecodeNullable(
          _$BusinessUnitTypeEnumMap, json['businessUnitType']),
      userId: json['userId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ExpenseToJson(Expense instance) => <String, dynamic>{
      'id': instance.id,
      if (instance.localId case final value?) 'localId': value,
      'date': instance.date.toIso8601String(),
      'motif': instance.motif,
      'amount': instance.amount,
      'category': _$ExpenseCategoryEnumMap[instance.category]!,
      if (instance.paymentMethod case final value?) 'paymentMethod': value,
      if (instance.attachmentUrls case final value?) 'attachmentUrls': value,
      if (instance.supplierId case final value?) 'supplierId': value,
      if (instance.beneficiary case final value?) 'beneficiary': value,
      if (instance.notes case final value?) 'notes': value,
      if (instance.userId case final value?) 'userId': value,
      if (instance.createdAt?.toIso8601String() case final value?)
        'createdAt': value,
      if (instance.updatedAt?.toIso8601String() case final value?)
        'updatedAt': value,
      if (instance.currencyCode case final value?) 'currencyCode': value,
      if (instance.supplierName case final value?) 'supplierName': value,
      if (instance.paidAmount case final value?) 'paidAmount': value,
      if (instance.exchangeRate case final value?) 'exchangeRate': value,
      if (_$ExpensePaymentStatusEnumMap[instance.paymentStatus]
          case final value?)
        'paymentStatus': value,
      if (instance.companyId case final value?) 'companyId': value,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
      if (instance.businessUnitCode case final value?)
        'businessUnitCode': value,
      if (_$BusinessUnitTypeEnumMap[instance.businessUnitType]
          case final value?)
        'businessUnitType': value,
    };

const _$ExpenseCategoryEnumMap = {
  ExpenseCategory.rent: 'rent',
  ExpenseCategory.utilities: 'utilities',
  ExpenseCategory.supplies: 'supplies',
  ExpenseCategory.salaries: 'salaries',
  ExpenseCategory.marketing: 'marketing',
  ExpenseCategory.transport: 'transport',
  ExpenseCategory.maintenance: 'maintenance',
  ExpenseCategory.other: 'other',
  ExpenseCategory.inventory: 'inventory',
  ExpenseCategory.equipment: 'equipment',
  ExpenseCategory.taxes: 'taxes',
  ExpenseCategory.insurance: 'insurance',
  ExpenseCategory.loan: 'loan',
  ExpenseCategory.office: 'office',
  ExpenseCategory.training: 'training',
  ExpenseCategory.travel: 'travel',
  ExpenseCategory.software: 'software',
  ExpenseCategory.advertising: 'advertising',
  ExpenseCategory.legal: 'legal',
  ExpenseCategory.manufacturing: 'manufacturing',
  ExpenseCategory.consulting: 'consulting',
  ExpenseCategory.research: 'research',
  ExpenseCategory.fuel: 'fuel',
  ExpenseCategory.entertainment: 'entertainment',
  ExpenseCategory.communication: 'communication',
};

const _$ExpensePaymentStatusEnumMap = {
  ExpensePaymentStatus.paid: 'paid',
  ExpensePaymentStatus.partial: 'partial',
  ExpensePaymentStatus.unpaid: 'unpaid',
  ExpensePaymentStatus.credit: 'credit',
};

const _$BusinessUnitTypeEnumMap = {
  BusinessUnitType.company: 'company',
  BusinessUnitType.branch: 'branch',
  BusinessUnitType.pos: 'pos',
};
