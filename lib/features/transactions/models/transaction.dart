import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 10)
class Transaction extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String currency; // 'CDF' ou 'USD'

  @HiveField(4)
  final String type; // e.g., 'sale', 'expense', 'payment_in', 'payment_out'

  @HiveField(5)
  final String description;

  @HiveField(6)
  final String status; // 'completed', 'pending', 'cancelled'

  @HiveField(7)
  final String? paymentMethodId;

  @HiveField(8)
  final String? relatedEntityId; // ID de l'entité liée (vente, achat, etc.)

  @HiveField(9)
  final String? relatedEntityType; // Type de l'entité liée ('sale', 'purchase', etc.)

  const Transaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.currency,
    required this.type,
    required this.description,
    required this.status,
    this.paymentMethodId,
    this.relatedEntityId,
    this.relatedEntityType,
  });

  // Helper getter to determine if this transaction is an expense
  bool get isExpense => type.toLowerCase() == 'expense';

  @override
  List<Object?> get props => [
        id,
        date,
        amount,
        currency,
        type,
        description,
        status,
        paymentMethodId,
        relatedEntityId,
        relatedEntityType
      ];

  // Clone this transaction with new values
  Transaction copyWith({
    String? id,
    DateTime? date,
    double? amount,
    String? currency,
    String? type,
    String? description,
    String? status,
    String? paymentMethodId,
    String? relatedEntityId,
    String? relatedEntityType,
  }) {
    return Transaction(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      description: description ?? this.description,
      status: status ?? this.status,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
    );
  }
}
