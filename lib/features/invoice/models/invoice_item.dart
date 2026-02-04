import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
// Assuming product might be linked

part 'invoice_item.g.dart';

@JsonSerializable()
class InvoiceItem extends Equatable {
  final String? id; // Nullable if creating, non-null if fetched
  final String productId;
  final String productName; // Denormalized for display
  final double quantity;
  final double unitPrice; // Price at the time of sale
  final double total;
  // final String? taxRateId; // Optional: if taxes are item-specific

  const InvoiceItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    // this.taxRateId,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => _$InvoiceItemFromJson(json);
  Map<String, dynamic> toJson() => _$InvoiceItemToJson(this);

  @override
  List<Object?> get props => [id, productId, productName, quantity, unitPrice, total];
}
