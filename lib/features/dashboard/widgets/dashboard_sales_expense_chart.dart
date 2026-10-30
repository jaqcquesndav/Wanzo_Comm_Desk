import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wanzo/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:wanzo/features/dashboard/widgets/expense_chart_widget.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_state.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/models/sale.dart';

/// Graphique « ventes et charges » du tableau de bord : la courbe, sa
/// trésorerie et son mode étendu. Un seul code pour le mode Général et les
/// modes métier. Les ventes et dépenses annulées sont écartées par
/// [SalesExpenseChartWidget] ; les dépenses viennent de l'[ExpenseBloc].
class DashboardSalesExpenseChart extends StatefulWidget {
  final List<Sale> sales;
  final double stockValueAtCost;
  final double stockValueAtSalePrice;
  final double potentialProfit;
  final int clientsServed;

  /// État étendu piloté par l'écran appelant (le tableau de bord Général le
  /// conserve quand il ouvre puis referme le journal agrandi). Sans lui, le
  /// widget tient son propre état.
  final bool? isExpanded;
  final VoidCallback? onToggleExpansion;

  const DashboardSalesExpenseChart({
    super.key,
    required this.sales,
    this.stockValueAtCost = 0.0,
    this.stockValueAtSalePrice = 0.0,
    this.potentialProfit = 0.0,
    this.clientsServed = 0,
    this.isExpanded,
    this.onToggleExpansion,
  });

  @override
  State<DashboardSalesExpenseChart> createState() =>
      _DashboardSalesExpenseChartState();
}

class _DashboardSalesExpenseChartState extends State<DashboardSalesExpenseChart>
    with AutomaticKeepAliveClientMixin {
  bool _expanded = false;

  // Le graphique garde sa période et son mode quand on fait défiler la
  // liste jusqu'au journal.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controlled = widget.isExpanded != null;
    return BlocBuilder<ExpenseBloc, ExpenseState>(
      builder: (context, expenseState) {
        final expenses =
            expenseState is ExpensesLoaded
                ? expenseState.expenses
                : <Expense>[];

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 250),
          child: SalesExpenseChartWidget(
            sales: widget.sales,
            expenses: expenses,
            isExpanded: controlled ? widget.isExpanded! : _expanded,
            onToggleExpansion:
                controlled
                    ? widget.onToggleExpansion
                    : () => setState(() => _expanded = !_expanded),
            // Données stock et clients pour le mode étendu
            stockValueAtCost: widget.stockValueAtCost,
            stockValueAtSalePrice: widget.stockValueAtSalePrice,
            potentialProfit: widget.potentialProfit,
            clientsServed: widget.clientsServed,
          ),
        );
      },
    );
  }
}

/// [DashboardSalesExpenseChart] alimenté directement par les blocs : ventes
/// de [SalesBloc], clients servis de [DashboardBloc], valeur du stock de
/// [InventoryBloc] si le métier tient un stock ([includeStock]).
class ModeDashboardChart extends StatelessWidget {
  final bool includeStock;

  const ModeDashboardChart({super.key, this.includeStock = true});

  @override
  Widget build(BuildContext context) {
    final salesState = context.watch<SalesBloc>().state;
    final dashState = context.watch<DashboardBloc>().state;
    final inventoryState =
        includeStock ? context.watch<InventoryBloc>().state : null;
    final stock = inventoryState is ProductsLoaded ? inventoryState : null;
    return DashboardSalesExpenseChart(
      sales: salesState is SalesLoaded ? salesState.sales : const <Sale>[],
      clientsServed:
          dashState is DashboardLoaded ? dashState.clientsServedToday : 0,
      stockValueAtCost: stock?.totalInventoryValueInCdf ?? 0.0,
      stockValueAtSalePrice: stock?.totalInventoryValueAtSalePrice ?? 0.0,
      potentialProfit: stock?.potentialProfit ?? 0.0,
    );
  }
}
