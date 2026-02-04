import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_method.g.dart';

/// Méthodes de paiement disponibles
@HiveType(typeId: 37)
@JsonEnum()
enum PaymentMethod {
  @HiveField(0)
  cash,        // Espèces
  @HiveField(1)
  card,        // Carte bancaire
  @HiveField(2)
  transfer,    // Virement
  @HiveField(3)
  mobileMoney, // Mobile Money
  @HiveField(4)
  check,       // Chèque
  @HiveField(5)
  other,       // Autre
}
