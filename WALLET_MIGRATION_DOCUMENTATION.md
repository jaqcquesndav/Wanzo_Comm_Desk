# 📚 Documentation Migration Wallet - Wanzo Mobile

## Vue d'ensemble

Cette documentation détaille la migration de la fonctionnalité **Financing** vers une structure **Wallet** plus complète. Le financement (crédit) est maintenant une sous-fonctionnalité du Wallet.

---

## 📁 1. Structure des dossiers

### Avant
```
lib/features/financing/
├── bloc/
├── models/
├── repositories/
├── screens/
├── services/
└── widgets/
```

### Après
```
lib/features/wallet/
├── bloc/                      # FinancingBloc (inchangé)
├── credit/                    # (nouveau dossier pour crédit - réservé)
├── models/
│   ├── financing_request.dart       # Existant
│   ├── financing_request.g.dart     # Existant
│   ├── institution_metadata.dart    # Existant
│   ├── payment_schedule.dart        # Existant
│   ├── wallet.dart                  # NOUVEAU
│   ├── wallet.g.dart                # NOUVEAU (généré)
│   ├── wallet_transaction.dart      # NOUVEAU
│   └── wallet_transaction.g.dart    # NOUVEAU (généré)
├── repositories/
├── screens/
│   ├── add_financing_request_screen.dart  # Existant
│   ├── financing_detail_screen.dart       # Existant
│   └── wallet_screen.dart                 # NOUVEAU
├── services/
│   ├── financing_api_service.dart         # Existant
│   └── wallet_api_service.dart            # NOUVEAU
└── widgets/
```

---

## 🔐 2. Contrôle d'accès par rôle

### 2.1 Extension UserRole (`lib/core/enums/user_role.dart`)

**Ajouter à la fin de `UserRoleExtension`** :

```dart
  /// Vérifie si ce rôle peut accéder au Wallet et aux fonctionnalités de financement
  /// Seuls les admins et comptables ont accès à ces fonctionnalités sensibles
  bool get canAccessWallet =>
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.accountant;

  /// Vérifie si ce rôle peut gérer les demandes de crédit/financement
  bool get canManageCredit =>
      this == UserRole.admin ||
      this == UserRole.superAdmin ||
      this == UserRole.accountant;
```

### 2.2 Créer WalletGuard (`lib/core/shared_widgets/wallet_guard.dart`)

```dart
// filepath: lib/core/shared_widgets/wallet_guard.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/features/auth/bloc/auth_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart';

/// Widget qui contrôle l'accès aux fonctionnalités Wallet/Financing
/// basé sur le rôle de l'utilisateur.
///
/// Seuls les utilisateurs avec les rôles `admin`, `superAdmin` ou `accountant`
/// peuvent voir le contenu protégé par ce widget.
///
/// Usage:
/// ```dart
/// WalletGuard(
///   child: WalletDashboard(),
///   // Optionnel: widget à afficher si non autorisé
///   fallback: Text('Accès non autorisé'),
/// )
/// ```
class WalletGuard extends StatelessWidget {
  /// Le widget à afficher si l'utilisateur a accès
  final Widget child;

  /// Widget optionnel à afficher si l'utilisateur n'a pas accès
  /// Par défaut, affiche un message d'accès refusé
  final Widget? fallback;

  /// Si true, ne montre rien au lieu du fallback (utile pour masquer des éléments de navigation)
  final bool hideIfUnauthorized;

  const WalletGuard({
    super.key,
    required this.child,
    this.fallback,
    this.hideIfUnauthorized = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          final role = state.user.role.toLowerCase();

          // Vérifier si le rôle permet l'accès au wallet
          if (_canAccessWallet(role)) {
            return child;
          }
        }

        // Utilisateur non autorisé
        if (hideIfUnauthorized) {
          return const SizedBox.shrink();
        }

        return fallback ?? _buildAccessDenied(context);
      },
    );
  }

  /// Vérifie si le rôle permet l'accès au Wallet/Financing
  bool _canAccessWallet(String role) {
    return role == 'admin' ||
        role == 'super_admin' ||
        role == 'superadmin' ||
        role == 'accountant';
  }

  /// Widget par défaut lorsque l'accès est refusé
  Widget _buildAccessDenied(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error.withAlpha(153),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.accessDenied ?? 'Accès refusé',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.walletAccessDeniedMessage ??
                  'Cette fonctionnalité est réservée aux administrateurs et comptables.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension pour vérifier rapidement l'accès wallet depuis un AuthState
extension WalletAccessExtension on AuthState {
  /// Vérifie si l'utilisateur authentifié peut accéder au wallet
  bool get canAccessWallet {
    if (this is AuthAuthenticated) {
      final role = (this as AuthAuthenticated).user.role.toLowerCase();
      return role == 'admin' ||
          role == 'super_admin' ||
          role == 'superadmin' ||
          role == 'accountant';
    }
    return false;
  }
}
```

---

## 📦 3. Nouveaux modèles

### 3.1 Wallet Model (`lib/features/wallet/models/wallet.dart`)

```dart
// filepath: lib/features/wallet/models/wallet.dart
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'wallet.g.dart';

/// Statut du wallet
@HiveType(typeId: 80)
enum WalletStatus {
  @HiveField(0)
  active,

  @HiveField(1)
  suspended,

  @HiveField(2)
  frozen,

  @HiveField(3)
  closed,
}

extension WalletStatusExtension on WalletStatus {
  String get apiValue {
    switch (this) {
      case WalletStatus.active:
        return 'active';
      case WalletStatus.suspended:
        return 'suspended';
      case WalletStatus.frozen:
        return 'frozen';
      case WalletStatus.closed:
        return 'closed';
    }
  }

  static WalletStatus fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return WalletStatus.active;
      case 'suspended':
        return WalletStatus.suspended;
      case 'frozen':
        return WalletStatus.frozen;
      case 'closed':
        return WalletStatus.closed;
      default:
        return WalletStatus.active;
    }
  }

  String get displayName {
    switch (this) {
      case WalletStatus.active:
        return 'Actif';
      case WalletStatus.suspended:
        return 'Suspendu';
      case WalletStatus.frozen:
        return 'Gelé';
      case WalletStatus.closed:
        return 'Fermé';
    }
  }
}

/// Limites du wallet
@HiveType(typeId: 81)
@JsonSerializable()
class WalletLimits extends Equatable {
  @HiveField(0)
  final double dailyLimit;

  @HiveField(1)
  final double monthlyLimit;

  @HiveField(2)
  final double singleTransactionLimit;

  @HiveField(3)
  final double minimumBalance;

  const WalletLimits({
    required this.dailyLimit,
    required this.monthlyLimit,
    required this.singleTransactionLimit,
    required this.minimumBalance,
  });

  factory WalletLimits.fromJson(Map<String, dynamic> json) =>
      _$WalletLimitsFromJson(json);

  Map<String, dynamic> toJson() => _$WalletLimitsToJson(this);

  @override
  List<Object?> get props => [
    dailyLimit,
    monthlyLimit,
    singleTransactionLimit,
    minimumBalance,
  ];
}

/// Informations KYC
@HiveType(typeId: 82)
@JsonSerializable()
class WalletKyc extends Equatable {
  @HiveField(0)
  final bool verified;

  @HiveField(1)
  final String level;

  @HiveField(2)
  final List<String> documents;

  const WalletKyc({
    required this.verified,
    required this.level,
    required this.documents,
  });

  factory WalletKyc.fromJson(Map<String, dynamic> json) =>
      _$WalletKycFromJson(json);

  Map<String, dynamic> toJson() => _$WalletKycToJson(this);

  @override
  List<Object?> get props => [verified, level, documents];
}

/// Modèle représentant le Wallet de l'entreprise
/// Conformité: Aligné avec payment-service (wallet PME)
@HiveType(typeId: 83)
@JsonSerializable(explicitToJson: true)
class Wallet extends Equatable {
  /// Identifiant unique du wallet (UUID)
  @HiveField(0)
  final String id;

  /// Référence unique lisible (ex: WAL-PME-20260110-ABC)
  @HiveField(1)
  final String reference;

  /// Type de propriétaire: "company"
  @HiveField(2)
  final String ownerType;

  /// ID de l'entreprise propriétaire
  @HiveField(3)
  final String ownerId;

  /// Nom de l'entreprise
  @HiveField(4)
  final String ownerName;

  /// Solde total du wallet
  @HiveField(5)
  final double balance;

  /// Solde disponible (moins les montants gelés)
  @HiveField(6)
  final double availableBalance;

  /// Montant gelé (réservations, litiges)
  @HiveField(7)
  final double frozenBalance;

  /// Devise du wallet (CDF, USD, XOF)
  @HiveField(8)
  final String currency;

  /// Statut du wallet
  @HiveField(9)
  @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)
  final WalletStatus status;

  /// Limites du wallet
  @HiveField(10)
  final WalletLimits? limits;

  /// Informations KYC
  @HiveField(11)
  final WalletKyc? kyc;

  /// Date de création
  @HiveField(12)
  final DateTime? createdAt;

  const Wallet({
    required this.id,
    required this.reference,
    required this.ownerType,
    required this.ownerId,
    required this.ownerName,
    required this.balance,
    required this.availableBalance,
    required this.frozenBalance,
    required this.currency,
    required this.status,
    this.limits,
    this.kyc,
    this.createdAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);

  Map<String, dynamic> toJson() => _$WalletToJson(this);

  static WalletStatus _statusFromJson(String? value) =>
      value != null
          ? WalletStatusExtension.fromApiValue(value)
          : WalletStatus.active;

  static String _statusToJson(WalletStatus status) => status.apiValue;

  Wallet copyWith({
    String? id,
    String? reference,
    String? ownerType,
    String? ownerId,
    String? ownerName,
    double? balance,
    double? availableBalance,
    double? frozenBalance,
    String? currency,
    WalletStatus? status,
    WalletLimits? limits,
    WalletKyc? kyc,
    DateTime? createdAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      balance: balance ?? this.balance,
      availableBalance: availableBalance ?? this.availableBalance,
      frozenBalance: frozenBalance ?? this.frozenBalance,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      limits: limits ?? this.limits,
      kyc: kyc ?? this.kyc,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    reference,
    ownerType,
    ownerId,
    ownerName,
    balance,
    availableBalance,
    frozenBalance,
    currency,
    status,
    limits,
    kyc,
    createdAt,
  ];
}
```

### 3.2 WalletTransaction Model (`lib/features/wallet/models/wallet_transaction.dart`)

```dart
// filepath: lib/features/wallet/models/wallet_transaction.dart
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'wallet_transaction.g.dart';

/// Types de transactions wallet
@HiveType(typeId: 84)
enum WalletTransactionType {
  @HiveField(0)
  creditDisbursement, // Crédit reçu de l'institution

  @HiveField(1)
  creditRepayment, // Remboursement de crédit

  @HiveField(2)
  deposit, // Dépôt mobile money

  @HiveField(3)
  withdrawal, // Retrait mobile money

  @HiveField(4)
  transfer, // Transfert interne

  @HiveField(5)
  fee, // Frais
}

extension WalletTransactionTypeExtension on WalletTransactionType {
  String get apiValue {
    switch (this) {
      case WalletTransactionType.creditDisbursement:
        return 'credit_disbursement';
      case WalletTransactionType.creditRepayment:
        return 'credit_repayment';
      case WalletTransactionType.deposit:
        return 'deposit';
      case WalletTransactionType.withdrawal:
        return 'withdrawal';
      case WalletTransactionType.transfer:
        return 'transfer';
      case WalletTransactionType.fee:
        return 'fee';
    }
  }

  static WalletTransactionType fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'credit_disbursement':
        return WalletTransactionType.creditDisbursement;
      case 'credit_repayment':
        return WalletTransactionType.creditRepayment;
      case 'deposit':
        return WalletTransactionType.deposit;
      case 'withdrawal':
        return WalletTransactionType.withdrawal;
      case 'transfer':
        return WalletTransactionType.transfer;
      case 'fee':
        return WalletTransactionType.fee;
      default:
        return WalletTransactionType.transfer;
    }
  }

  String get displayName {
    switch (this) {
      case WalletTransactionType.creditDisbursement:
        return 'Décaissement crédit';
      case WalletTransactionType.creditRepayment:
        return 'Remboursement crédit';
      case WalletTransactionType.deposit:
        return 'Dépôt';
      case WalletTransactionType.withdrawal:
        return 'Retrait';
      case WalletTransactionType.transfer:
        return 'Transfert';
      case WalletTransactionType.fee:
        return 'Frais';
    }
  }

  bool get isIncoming {
    return this == WalletTransactionType.creditDisbursement ||
        this == WalletTransactionType.deposit;
  }

  bool get isOutgoing {
    return this == WalletTransactionType.creditRepayment ||
        this == WalletTransactionType.withdrawal ||
        this == WalletTransactionType.fee;
  }
}

/// Statuts de transaction wallet
@HiveType(typeId: 85)
enum WalletTransactionStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  processing,

  @HiveField(2)
  completed,

  @HiveField(3)
  failed,

  @HiveField(4)
  cancelled,
}

extension WalletTransactionStatusExtension on WalletTransactionStatus {
  String get apiValue {
    switch (this) {
      case WalletTransactionStatus.pending:
        return 'pending';
      case WalletTransactionStatus.processing:
        return 'processing';
      case WalletTransactionStatus.completed:
        return 'completed';
      case WalletTransactionStatus.failed:
        return 'failed';
      case WalletTransactionStatus.cancelled:
        return 'cancelled';
    }
  }

  static WalletTransactionStatus fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return WalletTransactionStatus.pending;
      case 'processing':
        return WalletTransactionStatus.processing;
      case 'completed':
        return WalletTransactionStatus.completed;
      case 'failed':
        return WalletTransactionStatus.failed;
      case 'cancelled':
        return WalletTransactionStatus.cancelled;
      default:
        return WalletTransactionStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case WalletTransactionStatus.pending:
        return 'En attente';
      case WalletTransactionStatus.processing:
        return 'En cours';
      case WalletTransactionStatus.completed:
        return 'Terminée';
      case WalletTransactionStatus.failed:
        return 'Échouée';
      case WalletTransactionStatus.cancelled:
        return 'Annulée';
    }
  }
}

/// Opérateurs mobile money supportés
enum MobileMoneyOperator {
  airtelMoney, // AM
  orangeMoney, // OM
  mpesa, // MP
  africellMoney, // AF
}

extension MobileMoneyOperatorExtension on MobileMoneyOperator {
  String get code {
    switch (this) {
      case MobileMoneyOperator.airtelMoney:
        return 'AM';
      case MobileMoneyOperator.orangeMoney:
        return 'OM';
      case MobileMoneyOperator.mpesa:
        return 'MP';
      case MobileMoneyOperator.africellMoney:
        return 'AF';
    }
  }

  String get displayName {
    switch (this) {
      case MobileMoneyOperator.airtelMoney:
        return 'Airtel Money';
      case MobileMoneyOperator.orangeMoney:
        return 'Orange Money';
      case MobileMoneyOperator.mpesa:
        return 'M-Pesa (Vodacom)';
      case MobileMoneyOperator.africellMoney:
        return 'Africell Money';
    }
  }

  static MobileMoneyOperator fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'AM':
        return MobileMoneyOperator.airtelMoney;
      case 'OM':
        return MobileMoneyOperator.orangeMoney;
      case 'MP':
        return MobileMoneyOperator.mpesa;
      case 'AF':
        return MobileMoneyOperator.africellMoney;
      default:
        return MobileMoneyOperator.airtelMoney;
    }
  }
}

/// Modèle représentant une transaction wallet
@HiveType(typeId: 86)
@JsonSerializable(explicitToJson: true)
class WalletTransaction extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String reference;

  @HiveField(2)
  @JsonKey(fromJson: _typeFromJson, toJson: _typeToJson)
  final WalletTransactionType type;

  @HiveField(3)
  @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)
  final WalletTransactionStatus status;

  @HiveField(4)
  final String? approvalMode;

  @HiveField(5)
  final String? sourceWalletId;

  @HiveField(6)
  final String? destinationWalletId;

  @HiveField(7)
  final double amount;

  @HiveField(8)
  final double fees;

  @HiveField(9)
  final double netAmount;

  @HiveField(10)
  final String currency;

  @HiveField(11)
  final String? description;

  @HiveField(12)
  final String? contractId;

  @HiveField(13)
  final String? portfolioId;

  @HiveField(14)
  final String? companyId;

  @HiveField(15)
  final int? riskScore;

  @HiveField(16)
  final bool isFlagged;

  @HiveField(17)
  final String? initiatedBy;

  @HiveField(18)
  final DateTime? createdAt;

  @HiveField(19)
  final DateTime? completedAt;

  const WalletTransaction({
    required this.id,
    required this.reference,
    required this.type,
    required this.status,
    this.approvalMode,
    this.sourceWalletId,
    this.destinationWalletId,
    required this.amount,
    required this.fees,
    required this.netAmount,
    required this.currency,
    this.description,
    this.contractId,
    this.portfolioId,
    this.companyId,
    this.riskScore,
    this.isFlagged = false,
    this.initiatedBy,
    this.createdAt,
    this.completedAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson(json);

  Map<String, dynamic> toJson() => _$WalletTransactionToJson(this);

  static WalletTransactionType _typeFromJson(String? value) =>
      value != null
          ? WalletTransactionTypeExtension.fromApiValue(value)
          : WalletTransactionType.transfer;

  static String _typeToJson(WalletTransactionType type) => type.apiValue;

  static WalletTransactionStatus _statusFromJson(String? value) =>
      value != null
          ? WalletTransactionStatusExtension.fromApiValue(value)
          : WalletTransactionStatus.pending;

  static String _statusToJson(WalletTransactionStatus status) =>
      status.apiValue;

  @override
  List<Object?> get props => [
    id,
    reference,
    type,
    status,
    approvalMode,
    sourceWalletId,
    destinationWalletId,
    amount,
    fees,
    netAmount,
    currency,
    description,
    contractId,
    portfolioId,
    companyId,
    riskScore,
    isFlagged,
    initiatedBy,
    createdAt,
    completedAt,
  ];
}
```

---

## 🌐 4. Service API Wallet (`lib/features/wallet/services/wallet_api_service.dart`)

```dart
// filepath: lib/features/wallet/services/wallet_api_service.dart
import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/models/api_response.dart';
import 'package:wanzo/features/wallet/models/wallet.dart';
import 'package:wanzo/features/wallet/models/wallet_transaction.dart';

/// Service API pour les opérations Wallet PME
/// Conformité: Aligné avec gestion_commerciale_service/wallet
/// Préfixe: /commerce/api/v1/wallet
class WalletApiService {
  final ApiClient _apiClient;

  WalletApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  // =============================================================================
  // WALLET ENDPOINTS
  // =============================================================================

  /// Récupère le wallet de l'entreprise connectée
  /// GET /wallet/my-wallet
  Future<ApiResponse<Wallet>> getMyWallet() async {
    try {
      final response = await _apiClient.get(
        'wallet/my-wallet',
        requiresAuth: true,
      );

      if (response != null) {
        final wallet = Wallet.fromJson(response as Map<String, dynamic>);
        return ApiResponse<Wallet>(
          success: true,
          data: wallet,
          message: 'Wallet récupéré avec succès.',
          statusCode: 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(500, 'Réponse invalide');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de récupération du wallet: $e');
    }
  }

  /// Récupère le résumé des soldes du wallet
  /// GET /wallet/balance
  Future<ApiResponse<Map<String, dynamic>>> getBalance() async {
    try {
      final response = await _apiClient.get(
        'wallet/balance',
        requiresAuth: true,
      );

      if (response != null && response['summary'] != null) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response as Map<String, dynamic>,
          message: 'Solde récupéré avec succès.',
          statusCode: 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(500, 'Réponse invalide');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de récupération du solde: $e');
    }
  }

  /// Récupère les détails d'un wallet par ID
  /// GET /wallet/{walletId}
  Future<ApiResponse<Wallet>> getWalletById(String walletId) async {
    try {
      final response = await _apiClient.get(
        'wallet/$walletId',
        requiresAuth: true,
      );

      if (response != null) {
        final wallet = Wallet.fromJson(response as Map<String, dynamic>);
        return ApiResponse<Wallet>(
          success: true,
          data: wallet,
          message: 'Wallet récupéré avec succès.',
          statusCode: 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(500, 'Réponse invalide');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de récupération du wallet: $e');
    }
  }

  // =============================================================================
  // TRANSACTIONS ENDPOINTS
  // =============================================================================

  /// Liste les transactions du wallet
  /// GET /wallet/transactions/list
  Future<ApiResponse<List<WalletTransaction>>> getTransactions({
    String? walletId,
    WalletTransactionType? type,
    WalletTransactionStatus? status,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (walletId != null) queryParams['walletId'] = walletId;
      if (type != null) queryParams['type'] = type.apiValue;
      if (status != null) queryParams['status'] = status.apiValue;
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();

      final response = await _apiClient.get(
        'wallet/transactions/list',
        queryParameters: queryParams,
        requiresAuth: true,
      );

      if (response != null && response['data'] != null) {
        final transactions =
            (response['data'] as List)
                .map(
                  (json) =>
                      WalletTransaction.fromJson(json as Map<String, dynamic>),
                )
                .toList();

        return ApiResponse<List<WalletTransaction>>(
          success: true,
          data: transactions,
          message: 'Transactions récupérées avec succès.',
          statusCode: 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(500, 'Réponse invalide');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de récupération des transactions: $e');
    }
  }

  /// Récupère les détails d'une transaction par ID
  /// GET /wallet/transactions/{transactionId}
  Future<ApiResponse<WalletTransaction>> getTransactionById(
    String transactionId,
  ) async {
    try {
      final response = await _apiClient.get(
        'wallet/transactions/$transactionId',
        requiresAuth: true,
      );

      if (response != null) {
        final transaction = WalletTransaction.fromJson(
          response as Map<String, dynamic>,
        );
        return ApiResponse<WalletTransaction>(
          success: true,
          data: transaction,
          message: 'Transaction récupérée avec succès.',
          statusCode: 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(500, 'Réponse invalide');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de récupération de la transaction: $e');
    }
  }

  /// Récupère une transaction par sa référence
  /// GET /wallet/transactions/ref/{reference}
  Future<ApiResponse<WalletTransaction>> getTransactionByReference(
    String reference,
  ) async {
    try {
      final response = await _apiClient.get(
        'wallet/transactions/ref/$reference',
        requiresAuth: true,
      );

      if (response != null) {
        final transaction = WalletTransaction.fromJson(
          response as Map<String, dynamic>,
        );
        return ApiResponse<WalletTransaction>(
          success: true,
          data: transaction,
          message: 'Transaction récupérée avec succès.',
          statusCode: 200,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(500, 'Réponse invalide');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec de récupération de la transaction: $e');
    }
  }

  // =============================================================================
  // MOBILE MONEY OPERATIONS
  // =============================================================================

  /// Effectue un dépôt mobile money
  /// POST /wallet/deposit
  ///
  /// [amount] - Montant à déposer (minimum: 1)
  /// [clientPhone] - Numéro mobile money du payeur (format: +243XXXXXXXXX)
  /// [telecom] - Opérateur: AM (Airtel), OM (Orange), MP (M-Pesa), AF (Africell)
  /// [currency] - Devise (défaut: CDF)
  /// [description] - Description optionnelle
  Future<ApiResponse<Map<String, dynamic>>> deposit({
    required double amount,
    required String clientPhone,
    required String telecom,
    String currency = 'CDF',
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'clientPhone': clientPhone,
        'telecom': telecom,
        'currency': currency,
      };
      if (description != null) body['description'] = description;

      debugPrint(
        '[WalletAPI] 💰 Initiating deposit: $amount $currency via $telecom',
      );

      final response = await _apiClient.post(
        'wallet/deposit',
        body: body,
        requiresAuth: true,
      );

      if (response != null) {
        final status = response['status'] as String?;
        final message =
            status == 'completed'
                ? 'Dépôt de $amount $currency effectué avec succès'
                : 'Dépôt en cours de traitement. Confirmez sur votre téléphone.';

        debugPrint('[WalletAPI] ✅ Deposit response: $status');

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response as Map<String, dynamic>,
          message: message,
          statusCode: 201,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(500, 'Réponse invalide');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec du dépôt mobile money: $e');
    }
  }

  /// Effectue un retrait mobile money
  /// POST /wallet/withdraw
  ///
  /// [amount] - Montant à retirer (minimum: 1)
  /// [clientPhone] - Numéro mobile money destinataire
  /// [telecom] - Opérateur: AM (Airtel), OM (Orange), MP (M-Pesa), AF (Africell)
  /// [currency] - Devise (défaut: CDF)
  /// [description] - Description optionnelle
  Future<ApiResponse<Map<String, dynamic>>> withdraw({
    required double amount,
    required String clientPhone,
    required String telecom,
    String currency = 'CDF',
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'clientPhone': clientPhone,
        'telecom': telecom,
        'currency': currency,
      };
      if (description != null) body['description'] = description;

      debugPrint(
        '[WalletAPI] 💸 Initiating withdrawal: $amount $currency via $telecom',
      );

      final response = await _apiClient.post(
        'wallet/withdraw',
        body: body,
        requiresAuth: true,
      );

      if (response != null) {
        final status = response['status'] as String?;
        final message =
            status == 'completed'
                ? 'Retrait de $amount $currency effectué avec succès'
                : 'Retrait en cours de traitement.';

        debugPrint('[WalletAPI] ✅ Withdrawal response: $status');

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: response as Map<String, dynamic>,
          message: message,
          statusCode: 201,
        );
      } else {
        throw ApiExceptionFactory.fromStatusCode(500, 'Réponse invalide');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Échec du retrait mobile money: $e');
    }
  }
}
```

---

## 🗺️ 5. Navigation (app_router.dart)

### 5.1 Imports à ajouter

```dart
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/wallet/screens/add_financing_request_screen.dart';
import '../../features/wallet/screens/financing_detail_screen.dart';
import '../../features/wallet/models/financing_request.dart';
```

### 5.2 Route à ajouter

```dart
GoRoute(
  path: '/wallet',
  name: 'wallet',
  builder: (context, state) => const WalletScreen(),
),
```

---

## 💾 6. Hive Adapters (`lib/core/adapters/hive_adapters.dart`)

### 6.1 Imports à ajouter

```dart
import '../../features/wallet/models/wallet.dart'; // Wallet models (typeIds 80-83)
import '../../features/wallet/models/wallet_transaction.dart'; // WalletTransaction models (typeIds 84-86)
```

### 6.2 Enregistrements à ajouter (dans `registerHiveAdapters()`)

```dart
  // ============= WALLET MODELS (typeIds 80-86) =============
  if (!Hive.isAdapterRegistered(80)) {
    // typeId 80 pour WalletStatus
    Hive.registerAdapter(WalletStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(81)) {
    // typeId 81 pour WalletLimits
    Hive.registerAdapter(WalletLimitsAdapter());
  }
  if (!Hive.isAdapterRegistered(82)) {
    // typeId 82 pour WalletKyc
    Hive.registerAdapter(WalletKycAdapter());
  }
  if (!Hive.isAdapterRegistered(83)) {
    // typeId 83 pour Wallet
    Hive.registerAdapter(WalletAdapter());
  }
  if (!Hive.isAdapterRegistered(84)) {
    // typeId 84 pour WalletTransactionType
    Hive.registerAdapter(WalletTransactionTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(85)) {
    // typeId 85 pour WalletTransactionStatus
    Hive.registerAdapter(WalletTransactionStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(86)) {
    // typeId 86 pour WalletTransaction
    Hive.registerAdapter(WalletTransactionAdapter());
  }
```

---

## 🌍 7. Localisations

### 7.1 app_fr.arb (à ajouter à la fin avant `}`)

```json
  "accessDenied": "Accès refusé",
  "walletAccessDeniedMessage": "Cette fonctionnalité est réservée aux administrateurs et comptables.",
  "walletTitle": "Portefeuille",
  "walletBalance": "Solde disponible",
  "walletDeposit": "Dépôt",
  "walletWithdraw": "Retrait",
  "walletTransactions": "Transactions",
  "walletCredit": "Crédit",
  "walletCreditRequests": "Demandes de crédit",
  "walletMobileMoneyDeposit": "Dépôt Mobile Money",
  "walletMobileMoneyWithdraw": "Retrait Mobile Money"
```

### 7.2 app_en.arb (à ajouter à la fin avant `}`)

```json
  "accessDenied": "Access denied",
  "walletAccessDeniedMessage": "This feature is reserved for administrators and accountants.",
  "walletTitle": "Wallet",
  "walletBalance": "Available balance",
  "walletDeposit": "Deposit",
  "walletWithdraw": "Withdraw",
  "walletTransactions": "Transactions",
  "walletCredit": "Credit",
  "walletCreditRequests": "Credit requests",
  "walletMobileMoneyDeposit": "Mobile Money Deposit",
  "walletMobileMoneyWithdraw": "Mobile Money Withdraw"
```

---

## 🔄 8. Mise à jour des imports

### Rechercher et remplacer dans tout le projet :

| Ancien import | Nouveau import |
|--------------|----------------|
| `features/financing/` | `features/wallet/` |

**Fichiers concernés :**
- `lib/main.dart`
- `lib/core/adapters/hive_adapters.dart`
- `lib/core/navigation/app_router.dart`
- `lib/core/utils/hive_setup.dart`
- `lib/features/operations/bloc/operations_bloc.dart`
- `lib/features/operations/screens/operations_screen.dart`
- `lib/services/cache_management_service.dart`
- Tout autre fichier qui importe depuis `features/financing/`

---

## 🔧 9. Commandes à exécuter

Après avoir copié tous les fichiers :

```bash
# 1. Régénérer les localisations
flutter gen-l10n

# 2. Générer les fichiers .g.dart (Hive adapters + JSON serialization)
dart run build_runner build --delete-conflicting-outputs
```

---

## 📊 10. Résumé des TypeIds Hive

| TypeId | Classe | Description |
|--------|--------|-------------|
| 80 | `WalletStatus` | Enum statut wallet |
| 81 | `WalletLimits` | Limites du wallet |
| 82 | `WalletKyc` | Informations KYC |
| 83 | `Wallet` | Modèle principal |
| 84 | `WalletTransactionType` | Enum type transaction |
| 85 | `WalletTransactionStatus` | Enum statut transaction |
| 86 | `WalletTransaction` | Modèle transaction |

---

## 🔐 11. Rôles ayant accès au Wallet

| Rôle | Accès Wallet | Gérer Crédit |
|------|--------------|--------------|
| `admin` | ✅ | ✅ |
| `superAdmin` | ✅ | ✅ |
| `accountant` | ✅ | ✅ |
| `manager` | ❌ | ❌ |
| `cashier` | ❌ | ❌ |
| `sales` | ❌ | ❌ |
| `inventoryManager` | ❌ | ❌ |
| `staff` | ❌ | ❌ |
| `customerSupport` | ❌ | ❌ |

---

## 📱 12. Endpoints API Wallet

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/wallet/my-wallet` | Récupérer son wallet |
| `GET` | `/wallet/balance` | Récupérer le solde |
| `GET` | `/wallet/{id}` | Détails d'un wallet |
| `GET` | `/wallet/transactions/list` | Liste des transactions |
| `GET` | `/wallet/transactions/{id}` | Détails transaction |
| `GET` | `/wallet/transactions/ref/{ref}` | Transaction par référence |
| `POST` | `/wallet/deposit` | Dépôt mobile money |
| `POST` | `/wallet/withdraw` | Retrait mobile money |

---

## ✅ Checklist pour Desktop

- [ ] Renommer dossier `features/financing` → `features/wallet`
- [ ] Ajouter `canAccessWallet` et `canManageCredit` à `UserRole`
- [ ] Créer `WalletGuard` widget
- [ ] Créer `wallet.dart` model
- [ ] Créer `wallet_transaction.dart` model
- [ ] Créer `wallet_api_service.dart`
- [ ] Créer `wallet_screen.dart` (adapter pour Desktop)
- [ ] Mettre à jour `hive_adapters.dart`
- [ ] Mettre à jour `app_router.dart`
- [ ] Ajouter les localisations
- [ ] Mettre à jour tous les imports `features/financing` → `features/wallet`
- [ ] Exécuter `flutter gen-l10n`
- [ ] Exécuter `dart run build_runner build --delete-conflicting-outputs`
- [ ] Tester la compilation
