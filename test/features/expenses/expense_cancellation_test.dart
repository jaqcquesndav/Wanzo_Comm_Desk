import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/cancellation/document_cancellation.dart';
import 'package:wanzo/core/cancellation/pending_cancellations.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/expenses/services/expense_api_service.dart';

class _FakeExpenseApi extends Fake implements ExpenseApiService {
  Object? error;
  int cancelCalls = 0;
  int restoreCalls = 0;

  @override
  Future<Expense> cancelExpense(String id, {required String reason}) async {
    cancelCalls++;
    if (error != null) throw error!;
    return _expense(id).copyWith(
      status: Expense.cancelledStatus,
      cancelReason: reason,
    );
  }

  @override
  Future<Expense> restoreExpense(String id, {String? reason}) async {
    restoreCalls++;
    if (error != null) throw error!;
    return _expense(id);
  }
}

Expense _expense(String id, {String? syncStatus = 'synced', double amount = 2000}) =>
    Expense(
      id: id,
      date: DateTime(2026, 10, 27),
      motif: 'Transport',
      amount: amount,
      category: ExpenseCategory.transport,
      currencyCode: 'CDF',
      paidAmount: amount,
      paymentStatus: ExpensePaymentStatus.paid,
      syncStatus: syncStatus,
    );

void main() {
  late _FakeExpenseApi api;
  late ExpenseRepository repo;

  setUpAll(() async {
    Hive.init('${Directory.systemTemp.path}/wanzo_test_expense_cancellation');
    if (!Hive.isAdapterRegistered(ExpenseAdapter().typeId)) {
      Hive.registerAdapter(ExpenseAdapter());
    }
    if (!Hive.isAdapterRegistered(ExpenseCategoryAdapter().typeId)) {
      Hive.registerAdapter(ExpenseCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(ExpensePaymentStatusAdapter().typeId)) {
      Hive.registerAdapter(ExpensePaymentStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(BusinessUnitTypeAdapter().typeId)) {
      Hive.registerAdapter(BusinessUnitTypeAdapter());
    }
  });

  setUp(() async {
    api = _FakeExpenseApi();
    repo = ExpenseRepository(expenseApiService: api);
    await repo.init();
    await Hive.box<Expense>('expenses').clear();
    for (final name in [PendingCancellations.boxName, 'pendingExpensePayments']) {
      if (Hive.isBoxOpen(name)) await Hive.box(name).clear();
    }
    PendingCancellations.instance.resetForTest();
  });

  Box<Expense> box() => Hive.box<Expense>('expenses');

  test('annulation : conservée au statut annulé, hors des totaux', () async {
    await box().put('e1', _expense('e1'));
    await box().put('e2', _expense('e2', amount: 500));

    final outcome = await repo.cancelExpense(_expense('e1'), 'Doublon');
    expect(outcome.synced, isTrue);
    expect(box().get('e1')!.isCancelled, isTrue);
    expect((await repo.getAllExpenses()).map((e) => e.id), ['e2']);
    expect((await repo.getAllExpenses(includeCancelled: true)), hasLength(2));
    final period = await repo.getExpensesByDateRange(
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
    );
    expect(period.fold<double>(0, (t, e) => t + e.amount), 500);
  });

  test('motif obligatoire', () async {
    await box().put('e1', _expense('e1'));
    await expectLater(repo.cancelExpense(_expense('e1'), ' '), throwsStateError);
    expect(api.cancelCalls, 0);
  });

  test('hors ligne : en file puis rejouée', () async {
    await box().put('e1', _expense('e1'));
    api.error = NetworkException('coupure');
    final outcome = await repo.cancelExpense(_expense('e1'), 'Erreur de saisie');
    expect(outcome.synced, isFalse);
    expect(PendingCancellations.instance.isPending(CancellableDocument.expense, 'e1'), isTrue);

    api.error = null;
    await repo.flushPendingCancellations();
    expect(api.cancelCalls, 2);
    expect(PendingCancellations.instance.isPending(CancellableDocument.expense, 'e1'), isFalse);
    expect(box().get('e1')!.isCancelled, isTrue);
  });

  test('refus (droits) : la dépense reprend son état', () async {
    await box().put('e1', _expense('e1'));
    api.error = AuthorizationException('Interdit');
    await expectLater(repo.cancelExpense(_expense('e1'), 'Doublon'), throwsStateError);
    expect(box().get('e1')!.isCancelled, isFalse);
  });

  test('rétablissement : de nouveau dans les totaux', () async {
    await box().put('e1', _expense('e1'));
    await repo.cancelExpense(_expense('e1'), 'Doublon');
    final outcome = await repo.restoreExpense(box().get('e1')!);
    expect(api.restoreCalls, 1);
    expect(outcome.document.isCancelled, isFalse);
    expect((await repo.getAllExpenses()).map((e) => e.id), ['e1']);
  });
}
