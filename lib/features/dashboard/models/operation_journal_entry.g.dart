// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_journal_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OperationJournalEntryAdapter extends TypeAdapter<OperationJournalEntry> {
  @override
  final int typeId = 201;

  @override
  OperationJournalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OperationJournalEntry(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      description: fields[2] as String,
      type: fields[3] as OperationType,
      amount: fields[4] as double,
      relatedDocumentId: fields[5] as String?,
      quantity: fields[6] as double?,
      productId: fields[7] as String?,
      productName: fields[8] as String?,
      paymentMethod: fields[9] as String?,
      currencyCode: fields[10] as String?,
      isDebit: fields[11] as bool,
      isCredit: fields[12] as bool,
      balanceAfter: fields[13] as double,
      balancesByCurrency: (fields[14] as Map?)?.cast<String, double>(),
      supplierId: fields[15] as String?,
      supplierName: fields[16] as String?,
      customerId: fields[17] as String?,
      customerName: fields[18] as String?,
      cashBalance: fields[19] as double?,
      salesBalance: fields[20] as double?,
      stockValue: fields[21] as double?,
      cashBalancesByCurrency: (fields[22] as Map?)?.cast<String, double>(),
      salesBalancesByCurrency: (fields[23] as Map?)?.cast<String, double>(),
      stockValuesByCurrency: (fields[24] as Map?)?.cast<String, double>(),
      companyId: fields[25] as String?,
      businessUnitId: fields[26] as String?,
      businessUnitCode: fields[27] as String?,
      businessUnitType: fields[28] as BusinessUnitType?,
    );
  }

  @override
  void write(BinaryWriter writer, OperationJournalEntry obj) {
    writer
      ..writeByte(29)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.relatedDocumentId)
      ..writeByte(6)
      ..write(obj.quantity)
      ..writeByte(7)
      ..write(obj.productId)
      ..writeByte(8)
      ..write(obj.productName)
      ..writeByte(9)
      ..write(obj.paymentMethod)
      ..writeByte(10)
      ..write(obj.currencyCode)
      ..writeByte(11)
      ..write(obj.isDebit)
      ..writeByte(12)
      ..write(obj.isCredit)
      ..writeByte(13)
      ..write(obj.balanceAfter)
      ..writeByte(14)
      ..write(obj.balancesByCurrency)
      ..writeByte(15)
      ..write(obj.supplierId)
      ..writeByte(16)
      ..write(obj.supplierName)
      ..writeByte(17)
      ..write(obj.customerId)
      ..writeByte(18)
      ..write(obj.customerName)
      ..writeByte(19)
      ..write(obj.cashBalance)
      ..writeByte(20)
      ..write(obj.salesBalance)
      ..writeByte(21)
      ..write(obj.stockValue)
      ..writeByte(22)
      ..write(obj.cashBalancesByCurrency)
      ..writeByte(23)
      ..write(obj.salesBalancesByCurrency)
      ..writeByte(24)
      ..write(obj.stockValuesByCurrency)
      ..writeByte(25)
      ..write(obj.companyId)
      ..writeByte(26)
      ..write(obj.businessUnitId)
      ..writeByte(27)
      ..write(obj.businessUnitCode)
      ..writeByte(28)
      ..write(obj.businessUnitType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationJournalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OperationTypeAdapter extends TypeAdapter<OperationType> {
  @override
  final int typeId = 200;

  @override
  OperationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OperationType.saleCash;
      case 1:
        return OperationType.saleCredit;
      case 2:
        return OperationType.saleInstallment;
      case 3:
        return OperationType.stockIn;
      case 4:
        return OperationType.stockOut;
      case 5:
        return OperationType.cashIn;
      case 6:
        return OperationType.cashOut;
      case 7:
        return OperationType.customerPayment;
      case 8:
        return OperationType.supplierPayment;
      case 9:
        return OperationType.financingRequest;
      case 10:
        return OperationType.financingApproved;
      case 11:
        return OperationType.financingRepayment;
      case 12:
        return OperationType.other;
      default:
        return OperationType.saleCash;
    }
  }

  @override
  void write(BinaryWriter writer, OperationType obj) {
    switch (obj) {
      case OperationType.saleCash:
        writer.writeByte(0);
        break;
      case OperationType.saleCredit:
        writer.writeByte(1);
        break;
      case OperationType.saleInstallment:
        writer.writeByte(2);
        break;
      case OperationType.stockIn:
        writer.writeByte(3);
        break;
      case OperationType.stockOut:
        writer.writeByte(4);
        break;
      case OperationType.cashIn:
        writer.writeByte(5);
        break;
      case OperationType.cashOut:
        writer.writeByte(6);
        break;
      case OperationType.customerPayment:
        writer.writeByte(7);
        break;
      case OperationType.supplierPayment:
        writer.writeByte(8);
        break;
      case OperationType.financingRequest:
        writer.writeByte(9);
        break;
      case OperationType.financingApproved:
        writer.writeByte(10);
        break;
      case OperationType.financingRepayment:
        writer.writeByte(11);
        break;
      case OperationType.other:
        writer.writeByte(12);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
