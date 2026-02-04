// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_unit_enums.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BusinessUnitTypeAdapter extends TypeAdapter<BusinessUnitType> {
  @override
  final int typeId = 71;

  @override
  BusinessUnitType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BusinessUnitType.company;
      case 1:
        return BusinessUnitType.branch;
      case 2:
        return BusinessUnitType.pos;
      default:
        return BusinessUnitType.company;
    }
  }

  @override
  void write(BinaryWriter writer, BusinessUnitType obj) {
    switch (obj) {
      case BusinessUnitType.company:
        writer.writeByte(0);
        break;
      case BusinessUnitType.branch:
        writer.writeByte(1);
        break;
      case BusinessUnitType.pos:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessUnitTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BusinessUnitStatusAdapter extends TypeAdapter<BusinessUnitStatus> {
  @override
  final int typeId = 72;

  @override
  BusinessUnitStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BusinessUnitStatus.active;
      case 1:
        return BusinessUnitStatus.inactive;
      case 2:
        return BusinessUnitStatus.suspended;
      case 3:
        return BusinessUnitStatus.closed;
      default:
        return BusinessUnitStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, BusinessUnitStatus obj) {
    switch (obj) {
      case BusinessUnitStatus.active:
        writer.writeByte(0);
        break;
      case BusinessUnitStatus.inactive:
        writer.writeByte(1);
        break;
      case BusinessUnitStatus.suspended:
        writer.writeByte(2);
        break;
      case BusinessUnitStatus.closed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessUnitStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
