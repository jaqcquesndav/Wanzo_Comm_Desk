import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bank_account_info.g.dart';

@JsonSerializable()
class BankAccountInfo extends Equatable {
  final String id;
  final String accountNumber;
  final String accountName;
  final String bankName;
  final String bankCode;
  final String? branchCode;
  final String? swiftCode;
  final String? rib;
  final String? iban;
  final bool isDefault;
  final String status; // 'active', 'inactive', 'suspended'
  final String currency; // 'CDF', 'USD', 'EUR'
  final double? balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BankAccountInfo({
    required this.id,
    required this.accountNumber,
    required this.accountName,
    required this.bankName,
    required this.bankCode,
    this.branchCode,
    this.swiftCode,
    this.rib,
    this.iban,
    required this.isDefault,
    required this.status,
    required this.currency,
    this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankAccountInfo.fromJson(Map<String, dynamic> json) =>
      _$BankAccountInfoFromJson(json);

  Map<String, dynamic> toJson() => _$BankAccountInfoToJson(this);

  BankAccountInfo copyWith({
    String? id,
    String? accountNumber,
    String? accountName,
    String? bankName,
    String? bankCode,
    String? branchCode,
    String? swiftCode,
    String? rib,
    String? iban,
    bool? isDefault,
    String? status,
    String? currency,
    double? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BankAccountInfo(
      id: id ?? this.id,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      branchCode: branchCode ?? this.branchCode,
      swiftCode: swiftCode ?? this.swiftCode,
      rib: rib ?? this.rib,
      iban: iban ?? this.iban,
      isDefault: isDefault ?? this.isDefault,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    accountNumber,
    accountName,
    bankName,
    bankCode,
    branchCode,
    swiftCode,
    rib,
    iban,
    isDefault,
    status,
    currency,
    balance,
    createdAt,
    updatedAt,
  ];
}
