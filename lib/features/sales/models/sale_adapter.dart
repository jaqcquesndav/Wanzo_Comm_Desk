// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\sales\models\sale_adapter.dart
import 'package:hive/hive.dart';
import 'sale.dart';
import './sale_item.dart'; // Added import for SaleItem

/// Adaptateur Hive pour la classe SaleStatus
class SaleStatusAdapter extends TypeAdapter<SaleStatus> {
  @override
  final int typeId = 3;

  @override
  SaleStatus read(BinaryReader reader) {
    return SaleStatus.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, SaleStatus obj) {
    writer.writeInt(obj.index);
  }
}

/// Adaptateur Hive pour la classe SaleItem
class SaleItemAdapter extends TypeAdapter<SaleItem> {
  @override
  final int typeId = 41; // Corrected to match @HiveType(typeId: 41) in SaleItem model

  @override
  SaleItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleItem(
      productId: fields[0] as String,
      productName: fields[1] as String,
      quantity: fields[2] as int,
      unitPrice: fields[3] as double,
      totalPrice: fields[4] as double,
      currencyCode: fields[5] as String,
      exchangeRate: fields[6] as double,
      unitPriceInCdf: fields[7] as double,
      totalPriceInCdf: fields[8] as double,
      itemType: fields[9] as SaleItemType, // Added itemType
    );
  }

  @override
  void write(BinaryWriter writer, SaleItem obj) {
    writer.writeByte(10); // Updated field count to 10
    writer.writeByte(0);
    writer.write(obj.productId);
    writer.writeByte(1);
    writer.write(obj.productName);
    writer.writeByte(2);
    writer.write(obj.quantity);
    writer.writeByte(3);
    writer.write(obj.unitPrice);
    writer.writeByte(4);
    writer.write(obj.totalPrice);
    writer.writeByte(5);
    writer.write(obj.currencyCode);
    writer.writeByte(6);
    writer.write(obj.exchangeRate);
    writer.writeByte(7);
    writer.write(obj.unitPriceInCdf);
    writer.writeByte(8);
    writer.write(obj.totalPriceInCdf);
    writer.writeByte(9); // Added itemType
    writer.write(obj.itemType); // Added itemType
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

/// Adaptateur Hive pour la classe Sale
class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 7; // Corrigé pour correspondre à @HiveType(typeId: 7) dans la classe Sale

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    // Ensure all required fields for Sale constructor are present
    return Sale(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      customerId: fields[2] as String,
      customerName: fields[3] as String,
      items: (fields[4] as List).cast<SaleItem>(),
      totalAmountInCdf: fields[5] as double, // Corrected field name
      paidAmountInCdf: fields[6] as double,  // Corrected field name
      paymentMethod: fields[7] as String,
      status: fields[8] as SaleStatus,
      notes: fields[9] as String? ?? '', // Handle potential null for notes
      transactionCurrencyCode: fields[10] as String, // Added field
      transactionExchangeRate: fields[11] as double, // Added field
      totalAmountInTransactionCurrency: fields[12] as double, // Added field
      paidAmountInTransactionCurrency: fields[13] as double, // Added field
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer.writeByte(14); // Updated field count
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.date);
    writer.writeByte(2);
    writer.write(obj.customerId);
    writer.writeByte(3);
    writer.write(obj.customerName);
    writer.writeByte(4);
    writer.write(obj.items);
    writer.writeByte(5);
    writer.write(obj.totalAmountInCdf); // Corrected field name
    writer.writeByte(6);
    writer.write(obj.paidAmountInCdf); // Corrected field name
    writer.writeByte(7);
    writer.write(obj.paymentMethod);
    writer.writeByte(8);
    writer.write(obj.status);
    writer.writeByte(9);
    writer.write(obj.notes);
    writer.writeByte(10); // Added field
    writer.write(obj.transactionCurrencyCode);
    writer.writeByte(11); // Added field
    writer.write(obj.transactionExchangeRate);
    writer.writeByte(12); // Added field
    writer.write(obj.totalAmountInTransactionCurrency);
    writer.writeByte(13); // Added field
    writer.write(obj.paidAmountInTransactionCurrency);
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
