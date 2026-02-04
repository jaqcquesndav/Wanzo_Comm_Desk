import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mobile_money_account.g.dart';

@JsonSerializable()
class MobileMoneyAccount extends Equatable {
  final String id;
  final String phoneNumber;
  final String accountName;
  final String operator; // 'AM', 'OM', 'WAVE', 'MP', 'AF'
  final String operatorName; // 'Airtel Money', 'Orange Money', etc.
  final bool isDefault;
  final String status; // 'active', 'inactive', 'suspended'
  final String verificationStatus; // 'pending', 'verified', 'failed'
  final String currency; // 'CDF', 'USD'
  final double? dailyLimit;
  final double? monthlyLimit;
  final double? balance;
  final String purpose; // 'disbursement', 'collection', 'general'
  final DateTime createdAt;
  final DateTime updatedAt;

  const MobileMoneyAccount({
    required this.id,
    required this.phoneNumber,
    required this.accountName,
    required this.operator,
    required this.operatorName,
    required this.isDefault,
    required this.status,
    required this.verificationStatus,
    required this.currency,
    this.dailyLimit,
    this.monthlyLimit,
    this.balance,
    required this.purpose,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MobileMoneyAccount.fromJson(Map<String, dynamic> json) =>
      _$MobileMoneyAccountFromJson(json);

  Map<String, dynamic> toJson() => _$MobileMoneyAccountToJson(this);

  MobileMoneyAccount copyWith({
    String? id,
    String? phoneNumber,
    String? accountName,
    String? operator,
    String? operatorName,
    bool? isDefault,
    String? status,
    String? verificationStatus,
    String? currency,
    double? dailyLimit,
    double? monthlyLimit,
    double? balance,
    String? purpose,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MobileMoneyAccount(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountName: accountName ?? this.accountName,
      operator: operator ?? this.operator,
      operatorName: operatorName ?? this.operatorName,
      isDefault: isDefault ?? this.isDefault,
      status: status ?? this.status,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      currency: currency ?? this.currency,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      balance: balance ?? this.balance,
      purpose: purpose ?? this.purpose,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    phoneNumber,
    accountName,
    operator,
    operatorName,
    isDefault,
    status,
    verificationStatus,
    currency,
    dailyLimit,
    monthlyLimit,
    balance,
    purpose,
    createdAt,
    updatedAt,
  ];
}
