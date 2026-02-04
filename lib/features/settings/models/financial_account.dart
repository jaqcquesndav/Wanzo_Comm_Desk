import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../financing/models/financing_request.dart';

part 'financial_account.g.dart';

/// Type de compte financier
@HiveType(typeId: 43)
@JsonEnum()
enum FinancialAccountType {
  @HiveField(0)
  bankAccount,    // Compte bancaire
  @HiveField(1)
  mobileMoney,    // Mobile Money
}

/// Fournisseurs de Mobile Money disponibles
@HiveType(typeId: 44)
@JsonEnum()
enum MobileMoneyProvider {
  @HiveField(0)
  airtelMoney,    // Airtel Money
  @HiveField(1)
  orangeMoney,    // Orange Money
  @HiveField(2)
  mpesa,          // M-PESA
}

/// Modèle pour les comptes financiers (bancaires et Mobile Money)
@HiveType(typeId: 45)
@JsonSerializable(explicitToJson: true)
class FinancialAccount extends Equatable {
  /// Identifiant unique du compte
  @HiveField(0)
  final String id;

  /// Type de compte (bancaire ou Mobile Money)
  @HiveField(1)
  final FinancialAccountType type;

  /// Nom personnalisé du compte (défini par l'utilisateur)
  @HiveField(2)
  final String accountName;

  /// Indique si c'est le compte par défaut
  @HiveField(3)
  final bool isDefault;

  /// Date de création
  @HiveField(4)
  final DateTime createdAt;

  /// Date de dernière mise à jour
  @HiveField(5)
  final DateTime updatedAt;

  // Champs spécifiques aux comptes bancaires
  /// Institution financière (pour les comptes bancaires)
  @HiveField(6)
  final FinancialInstitution? bankInstitution;

  /// Numéro de compte bancaire
  @HiveField(7)
  final String? bankAccountNumber;

  /// Code SWIFT (pour les comptes bancaires)
  @HiveField(8)
  final String? swiftCode;

  // Champs spécifiques au Mobile Money
  /// Fournisseur de Mobile Money
  @HiveField(9)
  final MobileMoneyProvider? mobileMoneyProvider;

  /// Numéro de téléphone du compte Mobile Money
  @HiveField(10)
  final String? phoneNumber;

  /// Nom du titulaire du compte Mobile Money
  @HiveField(11)
  final String? accountHolderName;

  /// Code PIN (chiffré pour la sécurité - ne sera pas stocké en clair)
  @HiveField(12)
  final String? encryptedPin;

  const FinancialAccount({
    required this.id,
    required this.type,
    required this.accountName,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    // Champs bancaires
    this.bankInstitution,
    this.bankAccountNumber,
    this.swiftCode,
    // Champs Mobile Money
    this.mobileMoneyProvider,
    this.phoneNumber,
    this.accountHolderName,
    this.encryptedPin,
  });

  /// Constructeur pour créer un compte bancaire
  factory FinancialAccount.bankAccount({
    required String id,
    required String accountName,
    required FinancialInstitution bankInstitution,
    required String bankAccountNumber,
    required String swiftCode,
    bool isDefault = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return FinancialAccount(
      id: id,
      type: FinancialAccountType.bankAccount,
      accountName: accountName,
      isDefault: isDefault,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      bankInstitution: bankInstitution,
      bankAccountNumber: bankAccountNumber,
      swiftCode: swiftCode,
    );
  }

  /// Constructeur pour créer un compte Mobile Money
  factory FinancialAccount.mobileMoney({
    required String id,
    required String accountName,
    required MobileMoneyProvider provider,
    required String phoneNumber,
    required String accountHolderName,
    String? encryptedPin,
    bool isDefault = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return FinancialAccount(
      id: id,
      type: FinancialAccountType.mobileMoney,
      accountName: accountName,
      isDefault: isDefault,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      mobileMoneyProvider: provider,
      phoneNumber: phoneNumber,
      accountHolderName: accountHolderName,
      encryptedPin: encryptedPin,
    );
  }

  /// Validation pour les comptes bancaires
  bool get isValidBankAccount {
    if (type != FinancialAccountType.bankAccount) return false;
    return bankInstitution != null && 
           bankAccountNumber != null && 
           bankAccountNumber!.isNotEmpty &&
           swiftCode != null && 
           swiftCode!.isNotEmpty;
  }

  /// Validation pour les comptes Mobile Money
  bool get isValidMobileMoneyAccount {
    if (type != FinancialAccountType.mobileMoney) return false;
    return mobileMoneyProvider != null &&
           phoneNumber != null && 
           phoneNumber!.isNotEmpty &&
           accountHolderName != null && 
           accountHolderName!.isNotEmpty;
  }

  /// Nom d'affichage du fournisseur Mobile Money
  String get providerDisplayName {
    switch (mobileMoneyProvider) {
      case MobileMoneyProvider.airtelMoney:
        return 'Airtel Money';
      case MobileMoneyProvider.orangeMoney:
        return 'Orange Money';
      case MobileMoneyProvider.mpesa:
        return 'M-PESA';
      default:
        return 'Mobile Money';
    }
  }

  /// Description courte du compte pour l'affichage
  String get displayDescription {
    switch (type) {
      case FinancialAccountType.bankAccount:
        return '$bankInstitution - ${bankAccountNumber?.replaceRange(0, bankAccountNumber!.length - 4, '*' * (bankAccountNumber!.length - 4))}';
      case FinancialAccountType.mobileMoney:
        return '$providerDisplayName - ${phoneNumber?.replaceRange(0, phoneNumber!.length - 4, '*' * (phoneNumber!.length - 4))}';
    }
  }

  factory FinancialAccount.fromJson(Map<String, dynamic> json) => _$FinancialAccountFromJson(json);
  Map<String, dynamic> toJson() => _$FinancialAccountToJson(this);

  FinancialAccount copyWith({
    String? id,
    FinancialAccountType? type,
    String? accountName,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    FinancialInstitution? bankInstitution,
    String? bankAccountNumber,
    String? swiftCode,
    MobileMoneyProvider? mobileMoneyProvider,
    String? phoneNumber,
    String? accountHolderName,
    String? encryptedPin,
  }) {
    return FinancialAccount(
      id: id ?? this.id,
      type: type ?? this.type,
      accountName: accountName ?? this.accountName,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bankInstitution: bankInstitution ?? this.bankInstitution,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      swiftCode: swiftCode ?? this.swiftCode,
      mobileMoneyProvider: mobileMoneyProvider ?? this.mobileMoneyProvider,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      encryptedPin: encryptedPin ?? this.encryptedPin,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        accountName,
        isDefault,
        createdAt,
        updatedAt,
        bankInstitution,
        bankAccountNumber,
        swiftCode,
        mobileMoneyProvider,
        phoneNumber,
        accountHolderName,
        encryptedPin,
      ];
}
