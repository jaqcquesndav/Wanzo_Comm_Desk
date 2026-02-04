import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/utils/theme.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/dashboard/models/chart_period.dart';

/// Widget pour afficher les courbes des ventes et dépenses combinées
class SalesExpenseChartWidget extends StatefulWidget {
  final List<Sale> sales;
  final List<Expense> expenses;
  final bool isExpanded;
  final VoidCallback? onToggleExpansion;
  // Données additionnelles pour le mode étendu (confidentialité)
  final double stockValueAtCost;
  final double stockValueAtSalePrice;
  final double potentialProfit;
  final int clientsServed;

  const SalesExpenseChartWidget({
    super.key,
    required this.sales,
    required this.expenses,
    this.isExpanded = false,
    this.onToggleExpansion,
    this.stockValueAtCost = 0.0,
    this.stockValueAtSalePrice = 0.0,
    this.potentialProfit = 0.0,
    this.clientsServed = 0,
  });

  @override
  State<SalesExpenseChartWidget> createState() =>
      _SalesExpenseChartWidgetState();
}

class _SalesExpenseChartWidgetState extends State<SalesExpenseChartWidget> {
  ChartPeriod _selectedPeriod = ChartPeriod.week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dailySales = _aggregateSalesByPeriod();
    final dailyExpenses = _aggregateExpensesByPeriod();

    final totalSales = dailySales.values.fold(0.0, (sum, val) => sum + val);
    final totalExpenses = dailyExpenses.values.fold(
      0.0,
      (sum, val) => sum + val,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 280, // Largeur minimale du graphique
        minHeight: 300, // Hauteur minimale du graphique
      ),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.all(WanzoTheme.spacingMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WanzoTheme.borderRadiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec statistiques et bouton expand/collapse
            Padding(
              padding: const EdgeInsets.all(WanzoTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et actions - responsive avec Wrap
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 400;

                      if (isCompact) {
                        // Layout vertical pour petits écrans
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Ventes vs Dépenses',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildPeriodSelector(context),
                                    if (widget.onToggleExpansion != null)
                                      IconButton(
                                        icon: Icon(
                                          widget.isExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: theme.colorScheme.primary,
                                        ),
                                        onPressed: widget.onToggleExpansion,
                                        tooltip:
                                            widget.isExpanded
                                                ? 'Réduire'
                                                : 'Agrandir',
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      // Layout horizontal pour grands écrans
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Ventes vs Dépenses',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: WanzoTheme.spacingSm),
                                _buildPeriodSelector(context),
                              ],
                            ),
                          ),
                          if (widget.onToggleExpansion != null)
                            IconButton(
                              icon: Icon(
                                widget.isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: widget.onToggleExpansion,
                              tooltip:
                                  widget.isExpanded ? 'Réduire' : 'Agrandir',
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: WanzoTheme.spacingSm),
                  // Légende responsive
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 300) {
                        // Layout vertical pour très petits écrans
                        return Column(
                          children: [
                            _buildLegendItem(
                              context,
                              'Ventes',
                              _formatAmount(totalSales),
                              WanzoTheme.success,
                              Icons.trending_up,
                            ),
                            const SizedBox(height: WanzoTheme.spacingXs),
                            _buildLegendItem(
                              context,
                              'Dépenses',
                              _formatAmount(totalExpenses),
                              WanzoTheme.danger,
                              Icons.trending_down,
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Flexible(
                            child: _buildLegendItem(
                              context,
                              'Ventes',
                              _formatAmount(totalSales),
                              WanzoTheme.success,
                              Icons.trending_up,
                            ),
                          ),
                          Flexible(
                            child: _buildLegendItem(
                              context,
                              'Dépenses',
                              _formatAmount(totalExpenses),
                              WanzoTheme.danger,
                              Icons.trending_down,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Graphique combiné
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: widget.isExpanded ? 350 : 200,
              padding: const EdgeInsets.all(WanzoTheme.spacingMd),
              child:
                  (dailySales.isEmpty && dailyExpenses.isEmpty)
                      ? _buildEmptyState(context)
                      : _buildCombinedChart(dailySales, dailyExpenses, theme),
            ),

            // Statistiques détaillées en mode agrandi
            if (widget.isExpanded)
              _buildExpandedStats(context, dailySales, dailyExpenses),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: WanzoTheme.spacingSm),
          Text(
            'Aucune dépense enregistrée',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedChart(
    Map<DateTime, double> dailySales,
    Map<DateTime, double> dailyExpenses,
    ThemeData theme,
  ) {
    // Combiner toutes les dates
    final allDates =
        <DateTime>{...dailySales.keys, ...dailyExpenses.keys}.toList()..sort();

    final salesSpots = <FlSpot>[];
    final expensesSpots = <FlSpot>[];

    for (int i = 0; i < allDates.length; i++) {
      final date = allDates[i];
      final salesAmount = dailySales[date] ?? 0;
      final expensesAmount = dailyExpenses[date] ?? 0;

      salesSpots.add(FlSpot(i.toDouble(), salesAmount));
      expensesSpots.add(FlSpot(i.toDouble(), expensesAmount));
    }

    final maxSales =
        salesSpots.isEmpty
            ? 0.0
            : salesSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxExpenses =
        expensesSpots.isEmpty
            ? 0.0
            : expensesSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = (maxSales > maxExpenses ? maxSales : maxExpenses) * 1.2;

    // Éviter division par zéro et intervalles nuls
    final safeMaxY = maxY > 0 ? maxY : 100.0;
    final horizontalInterval = safeMaxY / 5;
    final leftInterval = safeMaxY / 4;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _getAxisInterval(allDates.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= allDates.length) {
                  return const SizedBox.shrink();
                }
                final date = allDates[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _formatDateLabel(date),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: leftInterval,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _formatCompactAmount(value),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            left: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ),
        minX: 0,
        maxX: (allDates.length - 1).toDouble(),
        minY: 0,
        maxY: safeMaxY,
        lineBarsData: [
          // Ligne des ventes (verte)
          LineChartBarData(
            spots: salesSpots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                WanzoTheme.success.withValues(alpha: 0.8),
                WanzoTheme.success,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: widget.isExpanded,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: WanzoTheme.success,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  WanzoTheme.success.withValues(alpha: 0.2),
                  WanzoTheme.success.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Ligne des dépenses (rouge)
          LineChartBarData(
            spots: expensesSpots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                WanzoTheme.danger.withValues(alpha: 0.8),
                WanzoTheme.danger,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: widget.isExpanded,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: WanzoTheme.danger,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => theme.colorScheme.surface,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final dateIndex = barSpot.x.toInt();
                if (dateIndex >= 0 && dateIndex < allDates.length) {
                  final date = allDates[dateIndex];
                  final isSales = barSpot.barIndex == 0;
                  final label = isSales ? 'Ventes' : 'Dépenses';
                  return LineTooltipItem(
                    '${DateFormat('dd MMM').format(date)}\n$label: ${_formatAmount(barSpot.y)}',
                    TextStyle(
                      color: isSales ? WanzoTheme.success : WanzoTheme.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedStats(
    BuildContext context,
    Map<DateTime, double> dailySales,
    Map<DateTime, double> dailyExpenses,
  ) {
    final theme = Theme.of(context);

    // Calculer le CUMUL TOTAL depuis le début de l'année (pas seulement la période affichée)
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final daysSinceStartOfYear = now.difference(startOfYear).inDays + 1;

    // Calculer le cumul de TOUTES les ventes/dépenses depuis le début de l'année
    double cumulativeSales = 0.0;
    double cumulativeExpenses = 0.0;

    for (final sale in widget.sales) {
      if (sale.date.isAfter(startOfYear.subtract(const Duration(days: 1))) &&
          sale.date.isBefore(now.add(const Duration(days: 1)))) {
        cumulativeSales += sale.totalAmountInCdf;
      }
    }

    for (final expense in widget.expenses) {
      if (expense.date.isAfter(startOfYear.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(now.add(const Duration(days: 1)))) {
        cumulativeExpenses += expense.amount;
      }
    }

    // Moyenne = Cumul total / Nombre de jours depuis début d'année
    final avgSales =
        daysSinceStartOfYear > 0 ? cumulativeSales / daysSinceStartOfYear : 0.0;
    final avgExpenses =
        daysSinceStartOfYear > 0
            ? cumulativeExpenses / daysSinceStartOfYear
            : 0.0;

    final maxSale =
        dailySales.isEmpty
            ? 0.0
            : dailySales.values.reduce((a, b) => a > b ? a : b);
    final maxExpense =
        dailyExpenses.isEmpty
            ? 0.0
            : dailyExpenses.values.reduce((a, b) => a > b ? a : b);

    // Dépenses par catégorie
    final expensesByCategory = <ExpenseCategory, double>{};
    for (final expense in widget.expenses) {
      expensesByCategory[expense.category] =
          (expensesByCategory[expense.category] ?? 0) + expense.amount;
    }
    final topCategories =
        expensesByCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(WanzoTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(WanzoTheme.borderRadiusMd),
          bottomRight: Radius.circular(WanzoTheme.borderRadiusMd),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques détaillées
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ventes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: WanzoTheme.success,
                      ),
                    ),
                    const SizedBox(height: WanzoTheme.spacingSm),
                    _buildDetailRow(
                      context,
                      'Moyenne/jour',
                      _formatAmount(avgSales),
                    ),
                    _buildDetailRow(context, 'Maximum', _formatAmount(maxSale)),
                  ],
                ),
              ),
              const SizedBox(width: WanzoTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dépenses',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: WanzoTheme.danger,
                      ),
                    ),
                    const SizedBox(height: WanzoTheme.spacingSm),
                    _buildDetailRow(
                      context,
                      'Moyenne/jour',
                      _formatAmount(avgExpenses),
                    ),
                    _buildDetailRow(
                      context,
                      'Maximum',
                      _formatAmount(maxExpense),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (topCategories.isNotEmpty) ...[
            const SizedBox(height: WanzoTheme.spacingMd),
            const Divider(),
            const SizedBox(height: WanzoTheme.spacingSm),
            Text(
              'Top Catégories de Dépenses',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: WanzoTheme.spacingSm),
            ...topCategories
                .take(3)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: WanzoTheme.spacingSm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          entry.key.icon,
                          size: 18,
                          color: WanzoTheme.danger,
                        ),
                        const SizedBox(width: WanzoTheme.spacingSm),
                        Expanded(
                          child: Text(
                            entry.key.displayName,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          _formatAmount(entry.value),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: WanzoTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],

          // Section Stock & Clients (informations confidentielles)
          if (widget.stockValueAtCost > 0 || widget.clientsServed > 0) ...[
            const SizedBox(height: WanzoTheme.spacingMd),
            const Divider(),
            const SizedBox(height: WanzoTheme.spacingSm),
            Text(
              'Stock & Performance',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: WanzoTheme.spacingSm),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventaire',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        context,
                        'Coût achat',
                        _formatAmount(widget.stockValueAtCost),
                      ),
                      _buildDetailRow(
                        context,
                        'Prix vente',
                        _formatAmount(widget.stockValueAtSalePrice),
                      ),
                      _buildDetailRow(
                        context,
                        'Bénéf. potentiel',
                        _formatAmount(widget.potentialProfit),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: WanzoTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activité',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        context,
                        'Clients servis',
                        widget.clientsServed.toString(),
                      ),
                      if (widget.potentialProfit > 0)
                        _buildDetailRow(
                          context,
                          'Marge (%)',
                          '${((widget.potentialProfit / widget.stockValueAtCost) * 100).toStringAsFixed(1)}%',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    return PopupMenuButton<ChartPeriod>(
      initialValue: _selectedPeriod,
      icon: Icon(
        _selectedPeriod.icon,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: 'Période: ${_selectedPeriod.displayName}',
      onSelected: (ChartPeriod period) {
        setState(() {
          _selectedPeriod = period;
        });
      },
      itemBuilder:
          (context) =>
              ChartPeriod.values.map((period) {
                return PopupMenuItem<ChartPeriod>(
                  value: period,
                  child: Row(
                    children: [
                      Icon(period.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(period.displayName),
                    ],
                  ),
                );
              }).toList(),
    );
  }

  Map<DateTime, double> _aggregateSalesByPeriod() {
    final Map<DateTime, double> aggregated = {};
    final dateRange = _selectedPeriod.getDateRange(DateTime.now());

    for (final sale in widget.sales) {
      // Filtrer uniquement les ventes dans la période
      if (sale.date.isAfter(dateRange.start) &&
          sale.date.isBefore(dateRange.end.add(const Duration(seconds: 1)))) {
        final dateKey = _getDateKey(sale.date);
        aggregated[dateKey] =
            (aggregated[dateKey] ?? 0) + sale.totalAmountInCdf;
      }
    }

    // Remplir les périodes vides avec 0
    return _fillMissingPeriods(aggregated, dateRange);
  }

  Map<DateTime, double> _aggregateExpensesByPeriod() {
    final Map<DateTime, double> aggregated = {};
    final dateRange = _selectedPeriod.getDateRange(DateTime.now());

    for (final expense in widget.expenses) {
      // Filtrer uniquement les dépenses dans la période
      if (expense.date.isAfter(dateRange.start) &&
          expense.date.isBefore(
            dateRange.end.add(const Duration(seconds: 1)),
          )) {
        final dateKey = _getDateKey(expense.date);
        aggregated[dateKey] = (aggregated[dateKey] ?? 0) + expense.amount;
      }
    }

    // Remplir les périodes vides avec 0
    return _fillMissingPeriods(aggregated, dateRange);
  }

  /// Obtient la clé de date selon la période sélectionnée
  DateTime _getDateKey(DateTime date) {
    switch (_selectedPeriod) {
      case ChartPeriod.day:
        // Agrégation par heure
        return DateTime(date.year, date.month, date.day, date.hour);
      case ChartPeriod.week:
      case ChartPeriod.month:
        // Agrégation par jour
        return DateTime(date.year, date.month, date.day);
      case ChartPeriod.quarter:
      case ChartPeriod.year:
        // Agrégation par mois
        return DateTime(date.year, date.month, 1);
    }
  }

  /// Remplit les périodes manquantes avec 0 pour avoir une continuité
  Map<DateTime, double> _fillMissingPeriods(
    Map<DateTime, double> data,
    DateTimeRange range,
  ) {
    final filled = <DateTime, double>{};
    DateTime current = _getDateKey(range.start);
    final end = _getDateKey(range.end);

    while (!current.isAfter(end)) {
      filled[current] = data[current] ?? 0.0;

      // Incrémenter selon la période
      switch (_selectedPeriod) {
        case ChartPeriod.day:
          current = current.add(const Duration(hours: 1));
          break;
        case ChartPeriod.week:
        case ChartPeriod.month:
          current = current.add(const Duration(days: 1));
          break;
        case ChartPeriod.quarter:
        case ChartPeriod.year:
          current = DateTime(current.year, current.month + 1, 1);
          break;
      }
    }

    return filled;
  }

  /// Obtient l'intervalle pour l'affichage des labels sur l'axe X
  double _getAxisInterval(int dataLength) {
    if (dataLength <= 7) return 1.0; // Afficher tous les points
    if (dataLength <= 15) return 2.0; // Afficher un point sur deux
    if (dataLength <= 30) {
      return (dataLength / 7).ceil().toDouble(); // ~7 labels
    }
    return (dataLength / 6)
        .ceil()
        .toDouble(); // ~6 labels pour grandes périodes
  }

  /// Formate le label de date selon la période sélectionnée
  String _formatDateLabel(DateTime date) {
    switch (_selectedPeriod) {
      case ChartPeriod.day:
        // Format: 14h, 15h, etc.
        return '${date.hour}h';
      case ChartPeriod.week:
        // Format: Lun 12, Mar 13, etc.
        final dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
        return '${dayNames[date.weekday - 1]} ${date.day}';
      case ChartPeriod.month:
        // Format: 12/11, 13/11, etc.
        return DateFormat('dd/MM').format(date);
      case ChartPeriod.quarter:
      case ChartPeriod.year:
        // Format: Jan, Fév, Mar pour trimestre et J, F, M pour année
        final monthNames = [
          'Jan',
          'Fév',
          'Mar',
          'Avr',
          'Mai',
          'Jun',
          'Jul',
          'Aoû',
          'Sep',
          'Oct',
          'Nov',
          'Déc',
        ];
        final monthName = monthNames[date.month - 1];
        return _selectedPeriod == ChartPeriod.year
            ? monthName.substring(0, 1)
            : monthName;
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M FC';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K FC';
    }
    return '${amount.toStringAsFixed(0)} FC';
  }

  String _formatCompactAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(0)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
