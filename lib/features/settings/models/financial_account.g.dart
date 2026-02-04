// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinancialAccountAdapter extends TypeAdapter<FinancialAccount> {
  @override
  final int typeId = 45;

  @override
  FinancialAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinancialAccount(
      id: fields[0] as String,
      type: fields[1] as FinancialAccountType,
      accountName: fields[2] as String,
      isDefault: fields[3] as bool,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      bankInstitution: fields[6] as FinancialInstitution?,
      bankAccountNumber: fields[7] as String?,
      swiftCode: fields[8] as String?,
      mobileMoneyProvider: fields[9] as MobileMoneyProvider?,
      phoneNumber: fields[10] as String?,
      accountHolderName: fields[11] as String?,
      encryptedPin: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FinancialAccount obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.accountName)
      ..writeByte(3)
      ..write(obj.isDefault)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.bankInstitution)
      ..writeByte(7)
      ..write(obj.bankAccountNumber)
      ..writeByte(8)
      ..write(obj.swiftCode)
      ..writeByte(9)
      ..write(obj.mobileMoneyProvider)
      ..writeByte(10)
      ..write(obj.phoneNumber)
      ..writeByte(11)
      ..write(obj.accountHolderName)
      ..writeByte(12)
      ..write(obj.encryptedPin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinancialAccountTypeAdapter extends TypeAdapter<FinancialAccountType> {
  @override
  final int typeId = 43;

  @override
  FinancialAccountType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FinancialAccountType.bankAccount;
      case 1:
        return FinancialAccountType.mobileMoney;
      default:
        return FinancialAccountType.bankAccount;
    }
  }

  @override
  void write(BinaryWriter writer, FinancialAccountType obj) {
    switch (obj) {
      case FinancialAccountType.bankAccount:
        writer.writeByte(0);
        break;
      case FinancialAccountType.mobileMoney:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialAccountTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MobileMoneyProviderAdapter extends TypeAdapter<MobileMoneyProvider> {
  @override
  final int typeId = 44;

  @override
  MobileMoneyProvider read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MobileMoneyProvider.airtelMoney;
      case 1:
        return MobileMoneyProvider.orangeMoney;
      case 2:
        return MobileMoneyProvider.mpesa;
      default:
        return MobileMoneyProvider.airtelMoney;
    }
  }

  @override
  void write(BinaryWriter writer, MobileMoneyProvider obj) {
    switch (obj) {
      case MobileMoneyProvider.airtelMoney:
        writer.writeByte(0);
        break;
      case MobileMoneyProvider.orangeMoney:
        writer.writeByte(1);
        break;
      case MobileMoneyProvider.mpesa:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MobileMoneyProviderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinancialAccount _$FinancialAccountFromJson(Map<String, dynamic> json) =>
    FinancialAccount(
      id: json['id'] as String,
      type: $enumDecode(_$FinancialAccountTypeEnumMap, json['type']),
      accountName: json['accountName'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      bankInstitution: $enumDecodeNullable(
          _$FinancialInstitutionEnumMap, json['bankInstitution']),
      bankAccountNumber: json['bankAccountNumber'] as String?,
      swiftCode: json['swiftCode'] as String?,
      mobileMoneyProvider: $enumDecodeNullable(
          _$MobileMoneyProviderEnumMap, json['mobileMoneyProvider']),
      phoneNumber: json['phoneNumber'] as String?,
      accountHolderName: json['accountHolderName'] as String?,
      encryptedPin: json['encryptedPin'] as String?,
    );

Map<String, dynamic> _$FinancialAccountToJson(FinancialAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$FinancialAccountTypeEnumMap[instance.type]!,
      'accountName': instance.accountName,
      'isDefault': instance.isDefault,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      if (_$FinancialInstitutionEnumMap[instance.bankInstitution]
          case final value?)
        'bankInstitution': value,
      if (instance.bankAccountNumber case final value?)
        'bankAccountNumber': value,
      if (instance.swiftCode case final value?) 'swiftCode': value,
      if (_$MobileMoneyProviderEnumMap[instance.mobileMoneyProvider]
          case final value?)
        'mobileMoneyProvider': value,
      if (instance.phoneNumber case final value?) 'phoneNumber': value,
      if (instance.accountHolderName case final value?)
        'accountHolderName': value,
      if (instance.encryptedPin case final value?) 'encryptedPin': value,
    };

const _$FinancialAccountTypeEnumMap = {
  FinancialAccountType.bankAccount: 'bankAccount',
  FinancialAccountType.mobileMoney: 'mobileMoney',
};

const _$FinancialInstitutionEnumMap = {
  FinancialInstitution.bonneMoisson: 'bonneMoisson',
  FinancialInstitution.tid: 'tid',
  FinancialInstitution.smico: 'smico',
  FinancialInstitution.tmb: 'tmb',
  FinancialInstitution.equitybcdc: 'equitybcdc',
  FinancialInstitution.wanzoPass: 'wanzoPass',
};

const _$MobileMoneyProviderEnumMap = {
  MobileMoneyProvider.airtelMoney: 'airtelMoney',
  MobileMoneyProvider.orangeMoney: 'orangeMoney',
  MobileMoneyProvider.mpesa: 'mpesa',
};
