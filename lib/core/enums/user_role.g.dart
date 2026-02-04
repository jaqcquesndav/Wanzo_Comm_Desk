// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_role.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserRoleAdapter extends TypeAdapter<UserRole> {
  @override
  final int typeId = 74;

  @override
  UserRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UserRole.admin;
      case 8:
        return UserRole.superAdmin;
      case 1:
        return UserRole.manager;
      case 2:
        return UserRole.accountant;
      case 3:
        return UserRole.cashier;
      case 4:
        return UserRole.sales;
      case 5:
        return UserRole.inventoryManager;
      case 6:
        return UserRole.staff;
      case 7:
        return UserRole.customerSupport;
      default:
        return UserRole.admin;
    }
  }

  @override
  void write(BinaryWriter writer, UserRole obj) {
    switch (obj) {
      case UserRole.admin:
        writer.writeByte(0);
        break;
      case UserRole.superAdmin:
        writer.writeByte(8);
        break;
      case UserRole.manager:
        writer.writeByte(1);
        break;
      case UserRole.accountant:
        writer.writeByte(2);
        break;
      case UserRole.cashier:
        writer.writeByte(3);
        break;
      case UserRole.sales:
        writer.writeByte(4);
        break;
      case UserRole.inventoryManager:
        writer.writeByte(5);
        break;
      case UserRole.staff:
        writer.writeByte(6);
        break;
      case UserRole.customerSupport:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
