// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentInfo _$PaymentInfoFromJson(Map<String, dynamic> json) => PaymentInfo(
      companyId: json['companyId'] as String,
      bankAccounts: (json['bankAccounts'] as List<dynamic>)
          .map((e) => BankAccountInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      mobileMoneyAccounts: (json['mobileMoneyAccounts'] as List<dynamic>)
          .map((e) => MobileMoneyAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
      paymentPreferences: PaymentPreferences.fromJson(
          json['paymentPreferences'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PaymentInfoToJson(PaymentInfo instance) =>
    <String, dynamic>{
      'companyId': instance.companyId,
      'bankAccounts': instance.bankAccounts.map((e) => e.toJson()).toList(),
      'mobileMoneyAccounts':
          instance.mobileMoneyAccounts.map((e) => e.toJson()).toList(),
      'paymentPreferences': instance.paymentPreferences.toJson(),
    };

PaymentPreferences _$PaymentPreferencesFromJson(Map<String, dynamic> json) =>
    PaymentPreferences(
      preferredMethod: json['preferredMethod'] as String,
      defaultBankAccountId: json['defaultBankAccountId'] as String?,
      defaultMobileMoneyAccountId:
          json['defaultMobileMoneyAccountId'] as String?,
      allowPartialPayments: json['allowPartialPayments'] as bool,
      allowAdvancePayments: json['allowAdvancePayments'] as bool,
    );

Map<String, dynamic> _$PaymentPreferencesToJson(PaymentPreferences instance) =>
    <String, dynamic>{
      'preferredMethod': instance.preferredMethod,
      if (instance.defaultBankAccountId case final value?)
        'defaultBankAccountId': value,
      if (instance.defaultMobileMoneyAccountId case final value?)
        'defaultMobileMoneyAccountId': value,
      'allowPartialPayments': instance.allowPartialPayments,
      'allowAdvancePayments': instance.allowAdvancePayments,
    };
