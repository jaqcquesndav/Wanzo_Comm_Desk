// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'institution_metadata.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InstitutionMetadataAdapter extends TypeAdapter<InstitutionMetadata> {
  @override
  final int typeId = 18;

  @override
  InstitutionMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InstitutionMetadata(
      institution: fields[0] as FinancialInstitution,
      portfolioId: fields[1] as String,
      institutionName: fields[2] as String,
      availableProducts: (fields[3] as List).cast<FinancialProductInfo>(),
      institutionConfig: (fields[4] as Map).cast<String, dynamic>(),
      lastUpdated: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, InstitutionMetadata obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.institution)
      ..writeByte(1)
      ..write(obj.portfolioId)
      ..writeByte(2)
      ..write(obj.institutionName)
      ..writeByte(3)
      ..write(obj.availableProducts)
      ..writeByte(4)
      ..write(obj.institutionConfig)
      ..writeByte(5)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinancialProductInfoAdapter extends TypeAdapter<FinancialProductInfo> {
  @override
  final int typeId = 19;

  @override
  FinancialProductInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinancialProductInfo(
      productId: fields[0] as String,
      productType: fields[1] as String,
      productName: fields[2] as String,
      description: fields[3] as String,
      minAmount: fields[4] as double,
      maxAmount: fields[5] as double,
      minDurationMonths: fields[6] as int,
      maxDurationMonths: fields[7] as int,
      baseInterestRate: fields[8] as double,
      requiredDocuments: (fields[9] as List).cast<String>(),
      productConfig: (fields[10] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, FinancialProductInfo obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productType)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.minAmount)
      ..writeByte(5)
      ..write(obj.maxAmount)
      ..writeByte(6)
      ..write(obj.minDurationMonths)
      ..writeByte(7)
      ..write(obj.maxDurationMonths)
      ..writeByte(8)
      ..write(obj.baseInterestRate)
      ..writeByte(9)
      ..write(obj.requiredDocuments)
      ..writeByte(10)
      ..write(obj.productConfig);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialProductInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
