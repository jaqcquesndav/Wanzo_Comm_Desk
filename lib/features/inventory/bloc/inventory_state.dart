import 'package:equatable/equatable.dart';
import '../models/product.dart';
import '../models/stock_transaction.dart'; // Added import

/// États du BLoC d'inventaire
abstract class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object?> get props => [];
}

/// État initial
class InventoryInitial extends InventoryState {
  const InventoryInitial();
}

/// État de chargement
class InventoryLoading extends InventoryState {
  const InventoryLoading();
}

/// État quand les produits sont chargés
class ProductsLoaded extends InventoryState {
  final List<Product> products;
  final double totalInventoryValueInCdf; // Valeur au coût d'achat
  final double totalInventoryValueAtSalePrice; // Valeur au prix de vente
  final int totalProductCount;
  final int lowStockCount;

  const ProductsLoaded({
    required this.products,
    required this.totalInventoryValueInCdf,
    required this.totalInventoryValueAtSalePrice,
    required this.totalProductCount,
    required this.lowStockCount,
  });

  /// Bénéfice potentiel = valeur au prix de vente - valeur au coût d'achat
  double get potentialProfit =>
      totalInventoryValueAtSalePrice - totalInventoryValueInCdf;

  @override
  List<Object?> get props => [
    products,
    totalInventoryValueInCdf,
    totalInventoryValueAtSalePrice,
    totalProductCount,
    lowStockCount,
  ];
}

/// État quand un seul produit est chargé (pour les détails)
class ProductLoaded extends InventoryState {
  final Product product;
  final List<StockTransaction> transactions;

  const ProductLoaded({required this.product, required this.transactions});

  @override
  List<Object?> get props => [product, transactions];
}

/// État quand les transactions sont chargées
class TransactionsLoaded extends InventoryState {
  final List<StockTransaction> transactions;

  const TransactionsLoaded({required this.transactions});

  @override
  List<Object?> get props => [transactions];
}

/// État d'opération réussie
class InventoryOperationSuccess extends InventoryState {
  final String message;

  const InventoryOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

/// État d'erreur
class InventoryError extends InventoryState {
  final String message;

  const InventoryError(this.message);

  @override
  List<Object?> get props => [message];
}
