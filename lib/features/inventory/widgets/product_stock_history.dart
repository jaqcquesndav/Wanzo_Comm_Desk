import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_client.dart';
import '../models/stock_transaction.dart';
import '../services/inventory_api_service.dart';

/// Historique réel des mouvements d'un produit, lu par pages sur
/// `GET stock-transactions?productId=&page=&limit=` (l'onglet affichait un
/// texte factice « disponible prochainement »). Hors ligne : les mouvements
/// connus sur l'appareil.
class ProductStockHistory extends StatefulWidget {
  const ProductStockHistory({
    super.key,
    required this.productId,
    this.localTransactions = const [],
    this.api,
    this.pageSize = 20,
  });

  final String productId;
  final List<StockTransaction> localTransactions;
  final InventoryApiService? api;
  final int pageSize;

  @override
  State<ProductStockHistory> createState() => _ProductStockHistoryState();
}

class _ProductStockHistoryState extends State<ProductStockHistory> {
  late final InventoryApiService _api =
      widget.api ?? InventoryApiServiceImpl(ApiClient());
  final List<StockTransaction> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final next = _page + 1;
    final res = await _api.getStockTransactions(
      productId: widget.productId,
      page: next,
      limit: widget.pageSize,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data != null) {
        _page = next;
        _items.addAll(res.data!);
        _hasMore = res.data!.length >= widget.pageSize;
      } else if (_items.isEmpty) {
        // Hors ligne : derniers mouvements connus sur l'appareil.
        _offline = true;
        _hasMore = false;
        final local = [...widget.localTransactions]
          ..sort((a, b) => b.date.compareTo(a.date));
        _items.addAll(local);
      } else {
        _hasMore = false;
      }
    });
  }

  static String _label(StockTransactionType t) {
    switch (t) {
      case StockTransactionType.purchase:
        return 'Achat';
      case StockTransactionType.sale:
        return 'Vente';
      case StockTransactionType.adjustment:
        return 'Ajustement';
      case StockTransactionType.transferIn:
        return 'Transfert reçu';
      case StockTransactionType.transferOut:
        return 'Transfert envoyé';
      case StockTransactionType.returned:
        return 'Retour client';
      case StockTransactionType.damaged:
        return 'Endommagé';
      case StockTransactionType.lost:
        return 'Perte';
      case StockTransactionType.initialStock:
        return 'Stock initial';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: theme.disabledColor),
            const SizedBox(height: 12),
            const Text('Aucun mouvement pour ce produit'),
          ],
        ),
      );
    }
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + 1 + (_offline ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (_offline && i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Hors ligne : mouvements connus sur cet appareil.',
              style: theme.textTheme.bodySmall,
            ),
          );
        }
        final index = i - (_offline ? 1 : 0);
        if (index == _items.length) {
          if (!_hasMore) return const SizedBox(height: 8);
          return Center(
            child: TextButton.icon(
              onPressed: _loading ? null : _loadMore,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Charger plus'),
            ),
          );
        }
        final t = _items[index];
        final delta = t.stockDelta;
        final entree = delta >= 0;
        final qte = delta.abs();
        final qteTexte =
            qte == qte.roundToDouble() ? qte.toStringAsFixed(0) : qte.toStringAsFixed(2);
        return ListTile(
          dense: true,
          leading: Icon(
            entree ? Icons.arrow_downward : Icons.arrow_upward,
            color: entree ? Colors.green.shade700 : theme.colorScheme.error,
          ),
          title: Text(_label(t.type)),
          subtitle: Text(
            [
              fmt.format(t.date.toLocal()),
              if ((t.notes ?? '').trim().isNotEmpty) t.notes!.trim(),
            ].join(' · '),
          ),
          trailing: Text(
            '${entree ? '+' : '-'}$qteTexte',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: entree ? Colors.green.shade700 : theme.colorScheme.error,
            ),
          ),
        );
      },
    );
  }
}
