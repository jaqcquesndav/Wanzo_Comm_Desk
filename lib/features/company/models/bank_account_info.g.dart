// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_account_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BankAccountInfo _$BankAccountInfoFromJson(Map<String, dynamic> json) =>
    BankAccountInfo(
      id: json['id'] as String,
      accountNumber: json['accountNumber'] as String,
      accountName: json['accountName'] as String,
      bankName: json['bankName'] as String,
      bankCode: json['bankCode'] as String,
      branchCode: json['branchCode'] as String?,
      swiftCode: json['swiftCode'] as String?,
      rib: json['rib'] as String?,
      iban: json['iban'] as String?,
      isDefault: json['isDefault'] as bool,
      status: json['status'] as String,
      currency: json['currency'] as String,
      balance: (json['balance'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$BankAccountInfoToJson(BankAccountInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'accountNumber': instance.accountNumber,
      'accountName': instance.accountName,
      'bankName': instance.bankName,
      'bankCode': instance.bankCode,
      if (instance.branchCode case final value?) 'branchCode': value,
      if (instance.swiftCode case final value?) 'swiftCode': value,
      if (instance.rib case final value?) 'rib': value,
      if (instance.iban case final value?) 'iban': value,
      'isDefault': instance.isDefault,
      'status': instance.status,
      'currency': instance.currency,
      if (instance.balance case final value?) 'balance': value,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
