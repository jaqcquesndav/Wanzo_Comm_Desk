import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'bank_account_info.dart';
import 'mobile_money_account.dart';

part 'payment_info.g.dart';

@JsonSerializable(explicitToJson: true)
class PaymentInfo extends Equatable {
  final String companyId;
  final List<BankAccountInfo> bankAccounts;
  final List<MobileMoneyAccount> mobileMoneyAccounts;
  final PaymentPreferences paymentPreferences;

  const PaymentInfo({
    required this.companyId,
    required this.bankAccounts,
    required this.mobileMoneyAccounts,
    required this.paymentPreferences,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) =>
      _$PaymentInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentInfoToJson(this);

  PaymentInfo copyWith({
    String? companyId,
    List<BankAccountInfo>? bankAccounts,
    List<MobileMoneyAccount>? mobileMoneyAccounts,
    PaymentPreferences? paymentPreferences,
  }) {
    return PaymentInfo(
      companyId: companyId ?? this.companyId,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      mobileMoneyAccounts: mobileMoneyAccounts ?? this.mobileMoneyAccounts,
      paymentPreferences: paymentPreferences ?? this.paymentPreferences,
    );
  }

  @override
  List<Object?> get props => [
    companyId,
    bankAccounts,
    mobileMoneyAccounts,
    paymentPreferences,
  ];
}

@JsonSerializable()
class PaymentPreferences extends Equatable {
  final String preferredMethod; // 'bank', 'mobile_money'
  final String? defaultBankAccountId;
  final String? defaultMobileMoneyAccountId;
  final bool allowPartialPayments;
  final bool allowAdvancePayments;

  const PaymentPreferences({
    required this.preferredMethod,
    this.defaultBankAccountId,
    this.defaultMobileMoneyAccountId,
    required this.allowPartialPayments,
    required this.allowAdvancePayments,
  });

  factory PaymentPreferences.fromJson(Map<String, dynamic> json) =>
      _$PaymentPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentPreferencesToJson(this);

  PaymentPreferences copyWith({
    String? preferredMethod,
    String? defaultBankAccountId,
    String? defaultMobileMoneyAccountId,
    bool? allowPartialPayments,
    bool? allowAdvancePayments,
  }) {
    return PaymentPreferences(
      preferredMethod: preferredMethod ?? this.preferredMethod,
      defaultBankAccountId: defaultBankAccountId ?? this.defaultBankAccountId,
      defaultMobileMoneyAccountId:
          defaultMobileMoneyAccountId ?? this.defaultMobileMoneyAccountId,
      allowPartialPayments: allowPartialPayments ?? this.allowPartialPayments,
      allowAdvancePayments: allowAdvancePayments ?? this.allowAdvancePayments,
    );
  }

  @override
  List<Object?> get props => [
    preferredMethod,
    defaultBankAccountId,
    defaultMobileMoneyAccountId,
    allowPartialPayments,
    allowAdvancePayments,
  ];
}
