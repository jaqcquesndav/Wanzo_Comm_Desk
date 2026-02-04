import 'package:hive/hive.dart';
import 'customer.dart';

/// Adaptateur Hive pour la classe Customer
class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 3;

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
      email: fields[3] as String? ?? '',
      address: fields[4] as String? ?? '',
      createdAt: fields[5] as DateTime,
      notes: fields[6] as String? ?? '',
      totalPurchases: fields[7] as double? ?? 0.0,
      lastPurchaseDate: fields[8] as DateTime?,
      category: fields[9] as CustomerCategory? ?? CustomerCategory.regular,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer.writeByte(10);
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
    writer.write(obj.category);
    writer.writeByte(7);
    writer.write(obj.totalPurchases);    writer.writeByte(8);
    writer.write(obj.lastPurchaseDate);
    writer.writeByte(9);
        writer.write(obj.email);
    writer.writeByte(4);
    writer.write(obj.address);
    writer.writeByte(5);
    writer.write(obj.createdAt);
    writer.writeByte(6);
    writer.write(obj.notes);
    writer.writeByte(7);
    writer.write(obj.totalPurchases);
    writer.writeByte(8);
    writer.write(obj.lastPurchaseDate);
    writer.writeByte(9);
    writer.write(obj.category);
  }
}

/// Adaptateur Hive pour l'énumération CustomerCategory
class CustomerCategoryAdapter extends TypeAdapter<CustomerCategory> {
  @override
  final int typeId = 4;

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
        return CustomerCategory.regular;
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
}
