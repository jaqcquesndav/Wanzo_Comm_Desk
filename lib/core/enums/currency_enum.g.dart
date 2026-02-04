// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_enum.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CurrencyAdapter extends TypeAdapter<Currency> {
  @override
  final int typeId = 70;

  @override
  Currency read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Currency.CDF;
      case 1:
        return Currency.USD;
      case 2:
        return Currency.FCFA;
      default:
        return Currency.CDF;
    }
  }

  @override
  void write(BinaryWriter writer, Currency obj) {
    switch (obj) {
      case Currency.CDF:
        writer.writeByte(0);
        break;
      case Currency.USD:
        writer.writeByte(1);
        break;
      case Currency.FCFA:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrencyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
