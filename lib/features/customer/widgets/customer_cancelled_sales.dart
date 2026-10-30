import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../invoice/utils/invoice_money.dart';
import '../../sales/bloc/sales_bloc.dart';
import '../../sales/models/sale.dart';
import '../../sales/repositories/sales_repository.dart';

/// Ventes annulées d'un client, dans une section repliée « Annulées ».
///
/// Simple trace : elles n'entrent dans aucun solde ni total de la fiche.
/// Rien n'est affiché si le client n'en a aucune.
class CustomerCancelledSales extends StatefulWidget {
  final String customerId;

  const CustomerCancelledSales({super.key, required this.customerId});

  @override
  State<CustomerCancelledSales> createState() => _CustomerCancelledSalesState();
}

class _CustomerCancelledSalesState extends State<CustomerCancelledSales> {
  late Future<List<Sale>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Sale>> _load() =>
      context.read<SalesRepository>().getCancelledSalesByCustomer(
        widget.customerId,
      );

  @override
  Widget build(BuildContext context) {
    return BlocListener<SalesBloc, SalesState>(
      // Une vente annulée ou rétablie ailleurs : la section suit.
      listenWhen: (_, current) => current is SaleCancellationDone,
      listener: (_, __) {
        if (!mounted) return;
        final f = _load();
        setState(() {
          _future = f;
        });
      },
      child: FutureBuilder<List<Sale>>(
        future: _future,
        builder: (context, snapshot) {
          final sales = snapshot.data ?? const <Sale>[];
          if (sales.isEmpty) return const SizedBox.shrink();
          final sorted = [...sales]..sort((a, b) => b.date.compareTo(a.date));
          return Card(
            key: const ValueKey('customer-cancelled-sales'),
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              leading: const Icon(Icons.block),
              title: Text('Annulées (${sales.length})'),
              subtitle: const Text('Hors des soldes et des totaux'),
              children: [
                for (final sale in sorted) _tile(context, sale),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Sale sale) {
    final money = InvoiceMoney.forSale(sale);
    final motif = sale.cancelReason;
    return ListTile(
      dense: true,
      title: Text(
        '${DateFormat('dd/MM/yyyy').format(sale.date)} : '
        '${formatCurrency(money.fromCdf(sale.totalAmountInCdf), money.currencyCode)}',
        style: const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      subtitle: motif == null ? null : Text('Motif : $motif'),
      trailing: const Icon(Icons.chevron_right),
      onTap:
          () => context.pushNamed(
            AppRoute.saleDetail.name,
            pathParameters: {'id': sale.id},
            extra: sale,
          ),
    );
  }
}
