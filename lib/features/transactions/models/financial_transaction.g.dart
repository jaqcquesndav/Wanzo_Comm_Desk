// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinancialTransactionAdapter extends TypeAdapter<FinancialTransaction> {
  @override
  final int typeId = 81;

  @override
  FinancialTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinancialTransaction(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      amount: fields[2] as double,
      type: fields[3] as TransactionType,
      description: fields[4] as String,
      category: fields[5] as String?,
      relatedParty: fields[6] as String?,
      paymentMethod: fields[7] as PaymentMethod?,
      referenceNumber: fields[8] as String?,
      status: fields[9] as TransactionStatus,
      notes: fields[10] as String?,
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      linkedDocumentId: fields[13] as String?,
      linkedDocumentType: fields[14] as String?,
      companyId: fields[15] as String?,
      businessUnitId: fields[16] as String?,
      businessUnitCode: fields[17] as String?,
      businessUnitType: fields[18] as BusinessUnitType?,
      currencyCode: fields[19] as String?,
      exchangeRate: fields[20] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, FinancialTransaction obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.relatedParty)
      ..writeByte(7)
      ..write(obj.paymentMethod)
      ..writeByte(8)
      ..write(obj.referenceNumber)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.linkedDocumentId)
      ..writeByte(14)
      ..write(obj.linkedDocumentType)
      ..writeByte(15)
      ..write(obj.companyId)
      ..writeByte(16)
      ..write(obj.businessUnitId)
      ..writeByte(17)
      ..write(obj.businessUnitCode)
      ..writeByte(18)
      ..write(obj.businessUnitType)
      ..writeByte(19)
      ..write(obj.currencyCode)
      ..writeByte(20)
      ..write(obj.exchangeRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 78;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.sale;
      case 1:
        return TransactionType.purchase;
      case 2:
        return TransactionType.customerPayment;
      case 3:
        return TransactionType.supplierPayment;
      case 4:
        return TransactionType.refund;
      case 5:
        return TransactionType.expense;
      case 6:
        return TransactionType.payroll;
      case 7:
        return TransactionType.taxPayment;
      case 8:
        return TransactionType.transfer;
      case 9:
        return TransactionType.income;
      case 10:
        return TransactionType.openingBalance;
      case 11:
        return TransactionType.other;
      default:
        return TransactionType.sale;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.sale:
        writer.writeByte(0);
        break;
      case TransactionType.purchase:
        writer.writeByte(1);
        break;
      case TransactionType.customerPayment:
        writer.writeByte(2);
        break;
      case TransactionType.supplierPayment:
        writer.writeByte(3);
        break;
      case TransactionType.refund:
        writer.writeByte(4);
        break;
      case TransactionType.expense:
        writer.writeByte(5);
        break;
      case TransactionType.payroll:
        writer.writeByte(6);
        break;
      case TransactionType.taxPayment:
        writer.writeByte(7);
        break;
      case TransactionType.transfer:
        writer.writeByte(8);
        break;
      case TransactionType.income:
        writer.writeByte(9);
        break;
      case TransactionType.openingBalance:
        writer.writeByte(10);
        break;
      case TransactionType.other:
        writer.writeByte(11);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionStatusAdapter extends TypeAdapter<TransactionStatus> {
  @override
  final int typeId = 79;

  @override
  TransactionStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionStatus.pending;
      case 1:
        return TransactionStatus.completed;
      case 2:
        return TransactionStatus.failed;
      case 3:
        return TransactionStatus.voided;
      case 4:
        return TransactionStatus.refunded;
      case 5:
        return TransactionStatus.partiallyRefunded;
      case 6:
        return TransactionStatus.pendingApproval;
      case 7:
        return TransactionStatus.cancelled;
      case 8:
        return TransactionStatus.onHold;
      default:
        return TransactionStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionStatus obj) {
    switch (obj) {
      case TransactionStatus.pending:
        writer.writeByte(0);
        break;
      case TransactionStatus.completed:
        writer.writeByte(1);
        break;
      case TransactionStatus.failed:
        writer.writeByte(2);
        break;
      case TransactionStatus.voided:
        writer.writeByte(3);
        break;
      case TransactionStatus.refunded:
        writer.writeByte(4);
        break;
      case TransactionStatus.partiallyRefunded:
        writer.writeByte(5);
        break;
      case TransactionStatus.pendingApproval:
        writer.writeByte(6);
        break;
      case TransactionStatus.cancelled:
        writer.writeByte(7);
        break;
      case TransactionStatus.onHold:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PaymentMethodAdapter extends TypeAdapter<PaymentMethod> {
  @override
  final int typeId = 80;

  @override
  PaymentMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PaymentMethod.cash;
      case 1:
        return PaymentMethod.bankTransfer;
      case 2:
        return PaymentMethod.check;
      case 3:
        return PaymentMethod.creditCard;
      case 4:
        return PaymentMethod.debitCard;
      case 5:
        return PaymentMethod.mobileMoney;
      case 6:
        return PaymentMethod.paypal;
      case 7:
        return PaymentMethod.other;
      default:
        return PaymentMethod.cash;
    }
  }

  @override
  void write(BinaryWriter writer, PaymentMethod obj) {
    switch (obj) {
      case PaymentMethod.cash:
        writer.writeByte(0);
        break;
      case PaymentMethod.bankTransfer:
        writer.writeByte(1);
        break;
      case PaymentMethod.check:
        writer.writeByte(2);
        break;
      case PaymentMethod.creditCard:
        writer.writeByte(3);
        break;
      case PaymentMethod.debitCard:
        writer.writeByte(4);
        break;
      case PaymentMethod.mobileMoney:
        writer.writeByte(5);
        break;
      case PaymentMethod.paypal:
        writer.writeByte(6);
        break;
      case PaymentMethod.other:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinancialTransaction _$FinancialTransactionFromJson(
        Map<String, dynamic> json) =>
    FinancialTransaction(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
      type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
      description: json['description'] as String,
      category: json['category'] as String?,
      relatedParty: json['relatedParty'] as String?,
      paymentMethod: FinancialTransaction._paymentMethodFromJson(
          json['paymentMethod'] as String?),
      referenceNumber: json['referenceNumber'] as String?,
      status: $enumDecode(_$TransactionStatusEnumMap, json['status']),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      linkedDocumentId: json['linkedDocumentId'] as String?,
      linkedDocumentType: json['linkedDocumentType'] as String?,
      companyId: json['companyId'] as String?,
      businessUnitId: json['businessUnitId'] as String?,
      businessUnitCode: json['businessUnitCode'] as String?,
      businessUnitType: FinancialTransaction._businessUnitTypeFromJson(
          json['businessUnitType'] as String?),
      currencyCode: json['currencyCode'] as String?,
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$FinancialTransactionToJson(
        FinancialTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'amount': instance.amount,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'description': instance.description,
      if (instance.category case final value?) 'category': value,
      if (instance.relatedParty case final value?) 'relatedParty': value,
      if (FinancialTransaction._paymentMethodToJson(instance.paymentMethod)
          case final value?)
        'paymentMethod': value,
      if (instance.referenceNumber case final value?) 'referenceNumber': value,
      'status': _$TransactionStatusEnumMap[instance.status]!,
      if (instance.notes case final value?) 'notes': value,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      if (instance.linkedDocumentId case final value?)
        'linkedDocumentId': value,
      if (instance.linkedDocumentType case final value?)
        'linkedDocumentType': value,
      if (instance.companyId case final value?) 'companyId': value,
      if (instance.businessUnitId case final value?) 'businessUnitId': value,
      if (instance.businessUnitCode case final value?)
        'businessUnitCode': value,
      if (FinancialTransaction._businessUnitTypeToJson(
              instance.businessUnitType)
          case final value?)
        'businessUnitType': value,
      if (instance.currencyCode case final value?) 'currencyCode': value,
      if (instance.exchangeRate case final value?) 'exchangeRate': value,
    };

const _$TransactionTypeEnumMap = {
  TransactionType.sale: 'sale',
  TransactionType.purchase: 'purchase',
  TransactionType.customerPayment: 'customer_payment',
  TransactionType.supplierPayment: 'supplier_payment',
  TransactionType.refund: 'refund',
  TransactionType.expense: 'expense',
  TransactionType.payroll: 'payroll',
  TransactionType.taxPayment: 'tax_payment',
  TransactionType.transfer: 'transfer',
  TransactionType.income: 'income',
  TransactionType.openingBalance: 'opening_balance',
  TransactionType.other: 'other',
};

const _$TransactionStatusEnumMap = {
  TransactionStatus.pending: 'pending',
  TransactionStatus.completed: 'completed',
  TransactionStatus.failed: 'failed',
  TransactionStatus.voided: 'voided',
  TransactionStatus.refunded: 'refunded',
  TransactionStatus.partiallyRefunded: 'partially_refunded',
  TransactionStatus.pendingApproval: 'pending_approval',
  TransactionStatus.cancelled: 'cancelled',
  TransactionStatus.onHold: 'on_hold',
};
