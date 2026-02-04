import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'invoice_item.dart';

part 'invoice.g.dart';

@JsonEnum()
enum InvoiceStatus {
  draft,
  sent,
  paid,
  overdue,
  voided,
  pending_payment, // Added for more granular status
  partially_paid, // Added for more granular status
}

@JsonSerializable(explicitToJson: true)
class Invoice extends Equatable {
  final String? id; // Nullable if creating, non-null if fetched
  final String invoiceNumber; // Generated or manually entered
  final String customerId; // Link to Customer model
  final String customerName; // Denormalized for display
  final DateTime date;
  final DateTime dueDate;
  final InvoiceStatus status;
  final List<InvoiceItem> items;
  final double subtotal;
  final double taxAmount; // Could be a sum of item taxes or a flat rate on subtotal
  final double totalAmount;
  final String? notes;
  final String? currencyCode; // e.g., "USD", "CDF"
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Invoice({
    this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.dueDate,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    this.notes,
    this.currencyCode = 'CDF',
    this.createdAt,
    this.updatedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => _$InvoiceFromJson(json);
  Map<String, dynamic> toJson() => _$InvoiceToJson(this);

  @override
  List<Object?> get props => [
        id,
        invoiceNumber,
        customerId,
        customerName,
        date,
        dueDate,
        status,
        items,
        subtotal,
        taxAmount,
        totalAmount,
        notes,
        currencyCode,
        createdAt,
        updatedAt,
      ];
}
