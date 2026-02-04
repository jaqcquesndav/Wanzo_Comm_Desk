import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense_model.freezed.dart';
part 'expense_model.g.dart';

@freezed
class Expense with _$Expense {
  const factory Expense({
    required String id,
    required String userId,
    required DateTime date,
    required double amount,
    required String motif,
    required String categoryId,
    required String paymentMethod,
    @Default([]) List<String> attachmentUrls,
    String? supplierId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}
