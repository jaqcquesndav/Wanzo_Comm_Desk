import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/services/platform_share_service.dart';
import 'package:wanzo/constants/spacing.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart'
    as old_settings_bloc;
import 'package:wanzo/features/settings/bloc/settings_state.dart'
    as old_settings_state;
import 'package:wanzo/features/settings/models/settings.dart'
    as old_settings_model;
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';
import 'package:wanzo/features/invoice/services/invoice_service.dart';
import 'package:wanzo/services/receipt_printer_service.dart';

/// Écran de détails d'une vente
class SaleDetailsScreen extends StatelessWidget {
  final Sale sale;

  const SaleDetailsScreen({super.key, required this.sale});

  // Constantes pour le layout responsive
  static const double _desktopBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    // Access currency settings
    final currencySettingsState = context.watch<CurrencySettingsCubit>().state;
    final Currency appDefaultCurrency =
        currencySettingsState
            .settings
            .activeCurrency; // Corrected: activeCurrency is the app's default/active
    final String transactionCurrencyCode =
        sale.transactionCurrencyCode ??
        appDefaultCurrency.code; // Provide a default value

    Color statusColor;
    String statusText;
    IconData statusIcon;

    // Déterminer la couleur et le texte en fonction du statut
    switch (sale.status) {
      case SaleStatus.pending:
        statusColor = Colors.amber;
        statusText = "En attente";
        statusIcon = Icons.pending;
        break;
      case SaleStatus.completed:
        statusColor = Colors.green;
        statusText = "Terminée";
        statusIcon = Icons.check_circle;
        break;
      case SaleStatus.partiallyPaid:
        statusColor = Colors.blue;
        statusText = "Partiellement payée";
        statusIcon = Icons.hourglass_bottom;
        break;
      case SaleStatus.cancelled:
        statusColor = Colors.red;
        statusText = "Annulée";
        statusIcon = Icons.cancel;
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Détails de la vente"),
            actions: [
              // Actions directes sur desktop
              if (isDesktop) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: "Modifier",
                  onPressed: () {
                    context.push(
                      '/sales/edit',
                      extra: {
                        'sale': sale,
                        'currencySettings':
                            context
                                .read<CurrencySettingsCubit>()
                                .state
                                .settings,
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: "Imprimer",
                  onPressed:
                      () => _showDocumentTypeSelectionDialog(
                        context,
                        isPrintAction: true,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: "Partager",
                  onPressed:
                      () => _showDocumentTypeSelectionDialog(
                        context,
                        isPrintAction: false,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: "Supprimer",
                  onPressed: () => _showDeleteConfirmation(context),
                ),
              ] else
                // Menu d'options pour mobile
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == "edit") {
                      // Naviguer vers l'écran d'édition
                      context.push(
                        '/sales/edit',
                        extra: {
                          'sale': sale,
                          'currencySettings':
                              context
                                  .read<CurrencySettingsCubit>()
                                  .state
                                  .settings,
                        },
                      );
                    } else if (value == "delete") {
                      _showDeleteConfirmation(context);
                    } else if (value == "print") {
                      _showDocumentTypeSelectionDialog(
                        context,
                        isPrintAction: true,
                      );
                    } else if (value == "share") {
                      _showDocumentTypeSelectionDialog(
                        context,
                        isPrintAction: false,
                      );
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem<String>(
                          value: "edit",
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text("Modifier"),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: "print",
                          child: Row(
                            children: [
                              Icon(Icons.print),
                              SizedBox(width: 8),
                              Text("Imprimer"),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: "share",
                          child: Row(
                            children: [
                              Icon(Icons.share),
                              SizedBox(width: 8),
                              Text("Partager"),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: "delete",
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                "Supprimer",
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
            ],
          ),
          body:
              isDesktop
                  ? _buildDesktopLayout(
                    context,
                    statusColor,
                    statusText,
                    statusIcon,
                    transactionCurrencyCode,
                    appDefaultCurrency,
                  )
                  : _buildMobileLayout(
                    context,
                    statusColor,
                    statusText,
                    statusIcon,
                    transactionCurrencyCode,
                    appDefaultCurrency,
                  ),
          // BottomNavigationBar uniquement pour mobile
          bottomNavigationBar:
              isDesktop ? null : _buildMobileBottomBar(context),
        );
      },
    );
  }

  /// Layout desktop: 2 colonnes (articles à gauche, résumé à droite)
  Widget _buildDesktopLayout(
    BuildContext context,
    Color statusColor,
    String statusText,
    IconData statusIcon,
    String transactionCurrencyCode,
    Currency appDefaultCurrency,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(WanzoSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colonne principale (articles vendus)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec statut
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Vente #${sale.id.substring(0, 8)}",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Chip(
                          label: Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: statusColor,
                          avatar: Icon(statusIcon, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: WanzoSpacing.md),
                // Titre de la section articles
                Text(
                  "Articles vendus",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: WanzoSpacing.sm),
                // Liste des articles sous forme de DataTable pour desktop
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        columns: const [
                          DataColumn(label: Text('Produit')),
                          DataColumn(label: Text('Quantité'), numeric: true),
                          DataColumn(
                            label: Text('Prix unitaire'),
                            numeric: true,
                          ),
                          DataColumn(label: Text('Total'), numeric: true),
                        ],
                        rows:
                            sale.items.map((item) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(item.productName)),
                                  DataCell(
                                    Text(item.quantity.toInt().toString()),
                                  ),
                                  DataCell(
                                    Text(
                                      formatCurrency(
                                        item.unitPrice,
                                        item.currencyCode,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      formatCurrency(
                                        item.totalPrice,
                                        item.currencyCode,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: WanzoSpacing.lg),
                // Boutons d'action pour desktop
                _buildDesktopActions(context),
              ],
            ),
          ),
          const SizedBox(width: WanzoSpacing.lg),
          // Sidebar (informations et résumé)
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations client et date
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Informations",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(),
                        _buildDetailRow(
                          context,
                          Icons.calendar_today,
                          "Date",
                          DateFormat("dd/MM/yyyy HH:mm").format(sale.date),
                        ),
                        const SizedBox(height: WanzoSpacing.sm),
                        _buildDetailRow(
                          context,
                          Icons.person,
                          "Client",
                          sale.customerName,
                        ),
                        const SizedBox(height: WanzoSpacing.sm),
                        _buildDetailRow(
                          context,
                          Icons.payment,
                          "Paiement",
                          sale.paymentMethod ?? 'Non spécifié',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: WanzoSpacing.md),
                // Résumé des montants
                Card(
                  margin: EdgeInsets.zero,
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Résumé",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(),
                        _buildAmountRow(
                          context,
                          "Total",
                          formatCurrency(
                            sale.totalAmountInTransactionCurrency ?? 0.0,
                            transactionCurrencyCode,
                          ),
                          isLarge: true,
                        ),
                        if (transactionCurrencyCode != appDefaultCurrency.code)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: WanzoSpacing.xxs,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  "(${formatCurrency(sale.totalAmountInCdf, appDefaultCurrency.code)})",
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        if (_hasTaxBreakdown) ...[
                          const SizedBox(height: WanzoSpacing.sm),
                          _buildAmountRow(
                            context,
                            "Montant HT",
                            formatCurrency(
                              _toTransactionCurrency(sale.amountHT ?? 0.0),
                              transactionCurrencyCode,
                            ),
                          ),
                          const SizedBox(height: WanzoSpacing.xs),
                          _buildAmountRow(
                            context,
                            "TVA",
                            formatCurrency(
                              _toTransactionCurrency(sale.taxAmount ?? 0.0),
                              transactionCurrencyCode,
                            ),
                          ),
                        ],
                        const SizedBox(height: WanzoSpacing.sm),
                        _buildAmountRow(
                          context,
                          "Payé",
                          formatCurrency(
                            sale.paidAmountInTransactionCurrency ?? 0.0,
                            transactionCurrencyCode,
                          ),
                        ),
                        if (transactionCurrencyCode != appDefaultCurrency.code)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: WanzoSpacing.xxs,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  "(${formatCurrency(sale.paidAmountInCdf, appDefaultCurrency.code)})",
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: WanzoSpacing.sm),
                        const Divider(),
                        _buildAmountRow(
                          context,
                          "Reste à payer",
                          formatCurrency(
                            (sale.totalAmountInTransactionCurrency ?? 0.0) -
                                (sale.paidAmountInTransactionCurrency ?? 0.0),
                            transactionCurrencyCode,
                          ),
                          valueColor: _getRemainingColor(),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Layout mobile: layout vertical classique
  Widget _buildMobileLayout(
    BuildContext context,
    Color statusColor,
    String statusText,
    IconData statusIcon,
    String transactionCurrencyCode,
    Currency appDefaultCurrency,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(WanzoSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec information générale
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(WanzoSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status de la vente
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Vente #${sale.id.substring(0, 8)}",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Chip(
                        label: Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: statusColor,
                        avatar: Icon(statusIcon, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: WanzoSpacing.sm),
                  // Information sur la date et le client
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: WanzoSpacing.xs),
                      Text(
                        DateFormat("dd/MM/yyyy HH:mm").format(sale.date),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: WanzoSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: WanzoSpacing.xs),
                      Text(
                        "Client: ${sale.customerName}",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: WanzoSpacing.sm),
                  // Information sur le paiement
                  Row(
                    children: [
                      const Icon(Icons.payment, size: 16),
                      const SizedBox(width: WanzoSpacing.xs),
                      Text(
                        "Mode de paiement: ${sale.paymentMethod ?? 'Non spécifié'}",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const Divider(),
                  // Résumé des montants
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        formatCurrency(
                          sale.totalAmountInTransactionCurrency ?? 0.0,
                          transactionCurrencyCode,
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  if (transactionCurrencyCode != appDefaultCurrency.code)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: WanzoSpacing.xxs,
                        bottom: WanzoSpacing.xs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "(${formatCurrency(sale.totalAmountInCdf, appDefaultCurrency.code)})",
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  if (_hasTaxBreakdown) ...[
                    const SizedBox(height: WanzoSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Montant HT"),
                        Text(
                          formatCurrency(
                            _toTransactionCurrency(sale.amountHT ?? 0.0),
                            transactionCurrencyCode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: WanzoSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("TVA"),
                        Text(
                          formatCurrency(
                            _toTransactionCurrency(sale.taxAmount ?? 0.0),
                            transactionCurrencyCode,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: WanzoSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Payé"),
                      Text(
                        formatCurrency(
                          sale.paidAmountInTransactionCurrency ?? 0.0,
                          transactionCurrencyCode,
                        ),
                      ),
                    ],
                  ),
                  if (transactionCurrencyCode != appDefaultCurrency.code)
                    Padding(
                      padding: const EdgeInsets.only(top: WanzoSpacing.xxs),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "(${formatCurrency(sale.paidAmountInCdf, appDefaultCurrency.code)})",
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: WanzoSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Reste à payer",
                        style: TextStyle(
                          color: _getRemainingColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formatCurrency(
                          (sale.totalAmountInTransactionCurrency ?? 0.0) -
                              (sale.paidAmountInTransactionCurrency ?? 0.0),
                          transactionCurrencyCode,
                        ),
                        style: TextStyle(
                          color: _getRemainingColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: WanzoSpacing.base),
          // Liste des articles vendus
          Text(
            "Articles vendus",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: WanzoSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sale.items.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = sale.items[index];
                return ListTile(
                  title: Text(item.productName),
                  subtitle: Text(
                    "${item.quantity.toInt()} × ${formatCurrency(item.unitPrice, item.currencyCode)}",
                  ),
                  trailing: Text(
                    formatCurrency(item.totalPrice, item.currencyCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Barre d'actions pour mobile
  Widget _buildMobileBottomBar(BuildContext context) {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WanzoSpacing.base,
          vertical: WanzoSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    () => _showDocumentTypeSelectionDialog(
                      context,
                      isPrintAction: true,
                    ),
                icon: const Icon(Icons.print),
                label: const Text("Imprimer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: WanzoSpacing.sm),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    () => _showDocumentTypeSelectionDialog(
                      context,
                      isPrintAction: false,
                    ),
                icon: const Icon(Icons.share),
                label: const Text("Partager"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (sale.status == SaleStatus.pending ||
                sale.status == SaleStatus.partiallyPaid) ...[
              const SizedBox(width: WanzoSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _markSaleAsCompleted(context),
                  icon: const Icon(Icons.check),
                  label: const Text("Terminer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Actions desktop sous forme de boutons
  Widget _buildDesktopActions(BuildContext context) {
    return Wrap(
      spacing: WanzoSpacing.sm,
      runSpacing: WanzoSpacing.sm,
      children: [
        ElevatedButton.icon(
          onPressed:
              () => _showDocumentTypeSelectionDialog(
                context,
                isPrintAction: true,
              ),
          icon: const Icon(Icons.print),
          label: const Text("Imprimer"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: WanzoSpacing.md,
              vertical: WanzoSpacing.sm,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed:
              () => _showDocumentTypeSelectionDialog(
                context,
                isPrintAction: false,
              ),
          icon: const Icon(Icons.share),
          label: const Text("Partager"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: WanzoSpacing.md,
              vertical: WanzoSpacing.sm,
            ),
          ),
        ),
        if (sale.status == SaleStatus.pending ||
            sale.status == SaleStatus.partiallyPaid)
          ElevatedButton.icon(
            onPressed: () => _markSaleAsCompleted(context),
            icon: const Icon(Icons.check),
            label: const Text("Marquer comme terminée"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: WanzoSpacing.md,
                vertical: WanzoSpacing.sm,
              ),
            ),
          ),
      ],
    );
  }

  /// Helper pour construire une ligne de détail
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: WanzoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper pour construire une ligne de montant
  Widget _buildAmountRow(
    BuildContext context,
    String label,
    String value, {
    bool isLarge = false,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style:
              isLarge
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: valueColor,
                  ),
        ),
        Text(
          value,
          style:
              isLarge
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: valueColor,
                  ),
        ),
      ],
    );
  }

  /// Couleur pour le montant restant
  Color _getRemainingColor() {
    return ((sale.totalAmountInTransactionCurrency ?? 0.0) -
                        (sale.paidAmountInTransactionCurrency ?? 0.0))
                    .abs() <
                0.001 ||
            (sale.paidAmountInTransactionCurrency ?? 0.0) >=
                (sale.totalAmountInTransactionCurrency ?? 0.0)
        ? Colors.green
        : Colors.red;
  }

  bool get _hasTaxBreakdown =>
      (sale.amountHT ?? 0) > 0 || (sale.taxAmount ?? 0) > 0;

  double _toTransactionCurrency(double amountInCdf) {
    final code = sale.transactionCurrencyCode ?? 'CDF';
    final rate = sale.transactionExchangeRate;
    if (code == 'CDF' || rate == null || rate <= 0) {
      return amountInCdf;
    }
    return amountInCdf / rate;
  }

  /// Marquer la vente comme terminée
  void _markSaleAsCompleted(BuildContext context) {
    final Sale updatedSale = sale.copyWith(
      status: SaleStatus.completed,
      paidAmountInTransactionCurrency: sale.totalAmountInTransactionCurrency,
      paidAmountInCdf: sale.totalAmountInCdf,
    );
    context.read<SalesBloc>().add(UpdateSale(updatedSale));
    GoRouter.of(context).pop();
  }

  /// Affiche une boîte de dialogue de confirmation pour supprimer la vente
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text("Confirmer la suppression"),
            content: const Text(
              "Êtes-vous sûr de vouloir supprimer cette vente ? Cette action est irréversible.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Annuler"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.read<SalesBloc>().add(DeleteSale(sale.id));
                  GoRouter.of(context).pop();
                },
                child: const Text(
                  "Supprimer",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  /// Détecte si la vente est un paiement en espèces
  bool get _hasCashTransaction {
    if (ReceiptPrinterService.isCashPayment(sale.paymentMethod)) return true;
    // Vérifier aussi le statut et d'éventuels paiements multiples
    return false;
  }

  /// Shows a dialog to select document type (Invoice or Receipt)
  void _showDocumentTypeSelectionDialog(
    BuildContext context, {
    required bool isPrintAction,
  }) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              isPrintAction ? "Imprimer le document" : "Partager le document",
            ),
            content: const Text(
              "Quel type de document souhaitez-vous générer ?",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _printOrShareInvoice(
                    context,
                    print: isPrintAction,
                    documentType: 'invoice',
                  );
                },
                child: const Text("Facture"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _printOrShareInvoice(
                    context,
                    print: isPrintAction,
                    documentType: 'receipt',
                  );
                },
                child: const Text("Ticket de caisse"),
              ),
              // Option d'impression thermique pour les ventes cash
              if (isPrintAction && _hasCashTransaction)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _printThermalReceipt(context);
                  },
                  icon: const Icon(Icons.receipt, size: 18),
                  label: const Text("Ticket thermique"),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Annuler"),
              ),
            ],
          ),
    );
  }

  /// Imprime la facture ou la partage
  void _printOrShareInvoice(
    BuildContext context, {
    required bool print,
    required String documentType,
  }) async {
    final invoiceService = InvoiceService();
    // The sale object already contains all necessary currency information.
    // The InvoiceService is expected to use sale.transactionCurrencyCode,
    // sale.totalAmountInTransactionCurrency, etc., for display,
    // and potentially sale.totalAmountInCdf for records if needed.

    // Retrieve old settings for invoice template compatibility
    final settingsBloc = context.read<old_settings_bloc.SettingsBloc>();
    final settingsState = settingsBloc.state;
    old_settings_model.Settings? legacySettings;

    if (settingsState is old_settings_state.SettingsLoaded) {
      legacySettings = settingsState.settings;
    } else if (settingsState is old_settings_state.SettingsUpdated) {
      legacySettings = settingsState.settings;
    }

    if (legacySettings == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de générer le document : anciens paramètres non chargés.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      String? pdfPath;
      // The Sale object now contains all necessary currency information.
      // InvoiceService's generateInvoicePdf and generateReceiptPdf methods
      // should be updated to use these fields (e.g., sale.transactionCurrencyCode,
      // sale.totalAmountInTransactionCurrency, sale.items[n].currencyCode, etc.)
      // The legacySettings are passed for template formatting (prefix, notes etc.)

      if (documentType == 'invoice') {
        pdfPath = await invoiceService.generateInvoicePdf(sale, legacySettings);
      } else if (documentType == 'receipt') {
        pdfPath = await invoiceService.generateReceiptPdf(sale, legacySettings);
      } else {
        // Should not happen with the dialog, but good to have a fallback or error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Type de document non valide.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Corrected condition: Removed pdfPath != null as it was deemed redundant by the analyzer
      if (pdfPath.isNotEmpty && context.mounted) {
        if (print) {
          // Utiliser PlatformShareService pour l'impression
          await PlatformShareService.instance.printPdfFile(
            filePath: pdfPath,
            documentName:
                documentType == 'invoice'
                    ? 'Invoice_${sale.id.substring(0, 8)}'
                    : 'Receipt_${sale.id.substring(0, 8)}',
          );
        } else {
          // Share the PDF using PlatformShareService for cross-platform support
          String subjectText =
              documentType == 'invoice'
                  ? 'Facture N° ${sale.id.substring(0, 8)}'
                  : 'Ticket N° ${sale.id.substring(0, 8)}';
          String bodyText =
              documentType == 'invoice'
                  ? 'Voici votre facture N° ${sale.id.substring(0, 8)} concernant ${sale.items.first.productName}.'
                  : 'Voici votre ticket de caisse N° ${sale.id.substring(0, 8)} concernant ${sale.items.first.productName}.';

          await PlatformShareService.instance.sharePdfFile(
            filePath: pdfPath,
            subject: subjectText,
            text: bodyText,
            context: context,
          );
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de générer le document. Chemin non valide.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la génération/partage du document: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Imprime un ticket thermique ESC/POS pour la vente en cours
  void _printThermalReceipt(BuildContext context) async {
    // Récupérer Settings depuis le Bloc
    final settingsBloc = context.read<old_settings_bloc.SettingsBloc>();
    final settingsState = settingsBloc.state;
    old_settings_model.Settings? legacySettings;

    if (settingsState is old_settings_state.SettingsLoaded) {
      legacySettings = settingsState.settings;
    } else if (settingsState is old_settings_state.SettingsUpdated) {
      legacySettings = settingsState.settings;
    }

    if (legacySettings == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres non chargés.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final printerService = ReceiptPrinterService();
    final savedPrinter = await printerService.getSavedPrinter();

    if (savedPrinter == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucune imprimante thermique configurée. '
              'Allez dans Paramètres → Imprimante.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impression du ticket en cours...')),
      );
    }

    final success = await printerService.printCashReceipt(sale, legacySettings);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Ticket imprimé avec succès !'
                : 'Échec de l\'impression. Vérifiez l\'imprimante.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
