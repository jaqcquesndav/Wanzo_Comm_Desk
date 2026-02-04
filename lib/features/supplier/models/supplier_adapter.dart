// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\supplier\models\supplier_adapter.dart
import 'package:hive/hive.dart';
import 'supplier.dart';

/// Adaptateur Hive pour la classe Supplier
class SupplierAdapter extends TypeAdapter<Supplier> {
  @override
  final int typeId = 22;

  @override
  Supplier read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return Supplier(
      id: fields[0] as String,
      name: fields[1] as String,
      phoneNumber: fields[2] as String,
      email: fields[3] as String? ?? '',      address: fields[4] as String? ?? '',
      notes: fields[5] as String? ?? '',
      category: fields[6] as SupplierCategory? ?? SupplierCategory.regular,
      totalPurchases: fields[7] as double? ?? 0.0,
      lastPurchaseDate: fields[8] as DateTime?,
      createdAt: fields[9] as DateTime,
      contactPerson: fields[10] as String? ?? '',
      paymentTerms: fields[11] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Supplier obj) {
    writer.writeByte(12);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.phoneNumber);
    writer.writeByte(3);
    writer.write(obj.email);
    writer.writeByte(4);
    writer.write(obj.address);
    writer.writeByte(5);
    writer.write(obj.notes);
    writer.writeByte(6);
    writer.write(obj.category);    writer.writeByte(7);
    writer.write(obj.totalPurchases);
    writer.writeByte(8);
    writer.write(obj.lastPurchaseDate);
    writer.writeByte(9);
    writer.write(obj.createdAt);
    writer.writeByte(10);
    writer.write(obj.contactPerson);
    writer.writeByte(11);
    writer.write(obj.paymentTerms);
  }
}

/// Adaptateur Hive pour la classe SupplierCategory
class SupplierCategoryAdapter extends TypeAdapter<SupplierCategory> {
  @override
  final int typeId = 23;

  @override
  SupplierCategory read(BinaryReader reader) {
    return SupplierCategory.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, SupplierCategory obj) {
    writer.writeInt(obj.index);
  }
}
