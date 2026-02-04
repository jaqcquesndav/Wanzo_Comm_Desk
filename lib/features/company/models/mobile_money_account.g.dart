// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mobile_money_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MobileMoneyAccount _$MobileMoneyAccountFromJson(Map<String, dynamic> json) =>
    MobileMoneyAccount(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      accountName: json['accountName'] as String,
      operator: json['operator'] as String,
      operatorName: json['operatorName'] as String,
      isDefault: json['isDefault'] as bool,
      status: json['status'] as String,
      verificationStatus: json['verificationStatus'] as String,
      currency: json['currency'] as String,
      dailyLimit: (json['dailyLimit'] as num?)?.toDouble(),
      monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble(),
      balance: (json['balance'] as num?)?.toDouble(),
      purpose: json['purpose'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$MobileMoneyAccountToJson(MobileMoneyAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phoneNumber': instance.phoneNumber,
      'accountName': instance.accountName,
      'operator': instance.operator,
      'operatorName': instance.operatorName,
      'isDefault': instance.isDefault,
      'status': instance.status,
      'verificationStatus': instance.verificationStatus,
      'currency': instance.currency,
      if (instance.dailyLimit case final value?) 'dailyLimit': value,
      if (instance.monthlyLimit case final value?) 'monthlyLimit': value,
      if (instance.balance case final value?) 'balance': value,
      'purpose': instance.purpose,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
