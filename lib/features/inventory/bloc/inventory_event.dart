import 'package:equatable/equatable.dart';
import '../models/product.dart';
import '../models/stock_transaction.dart'; // Added import

/// Événements du BLoC d'inventaire
abstract class InventoryEvent extends Equatable {
  const InventoryEvent();
  
  @override
  List<Object?> get props => [];
}

/// Charger tous les produits
class LoadProducts extends InventoryEvent {
  const LoadProducts();
}

/// Charger les produits par catégorie
class LoadProductsByCategory extends InventoryEvent {
  final ProductCategory category;
  
  const LoadProductsByCategory(this.category);
  
  @override
  List<Object?> get props => [category];
}

/// Rechercher des produits
class SearchProducts extends InventoryEvent {
  final String query;
  
  const SearchProducts(this.query);
  
  @override
  List<Object?> get props => [query];
}

/// Charger les produits avec stock bas
class LoadLowStockProducts extends InventoryEvent {
  const LoadLowStockProducts();
}

/// Charger un seul produit avec ses transactions
class LoadProduct extends InventoryEvent {
  final String id;
  
  const LoadProduct(this.id);
  
  @override
  List<Object?> get props => [id];
}

/// Ajouter un nouveau produit
class AddProduct extends InventoryEvent {
  final Product product;
  
  const AddProduct(this.product);
  
  @override
  List<Object?> get props => [product];
}

/// Mettre à jour un produit existant
class UpdateProduct extends InventoryEvent {
  final Product product;
  
  const UpdateProduct(this.product);
  
  @override
  List<Object?> get props => [product];
}

/// Supprimer un produit
class DeleteProduct extends InventoryEvent {
  final String id;
  
  const DeleteProduct(this.id);
  
  @override
  List<Object?> get props => [id];
}

/// Ajouter une transaction de stock
class AddStockTransaction extends InventoryEvent {
  final StockTransaction transaction;
  
  const AddStockTransaction(this.transaction);
  
  @override
  List<Object?> get props => [transaction];
}

/// Annuler une transaction de stock
class ReverseStockTransaction extends InventoryEvent {
  final String transactionId;
  
  const ReverseStockTransaction(this.transactionId);
  
  @override
  List<Object?> get props => [transactionId];
}

/// Charger toutes les transactions de stock
class LoadAllTransactions extends InventoryEvent {
  const LoadAllTransactions();
}

/// Charger les transactions pour un produit spécifique
class LoadProductTransactions extends InventoryEvent {
  final String productId;
  
  const LoadProductTransactions(this.productId);
  
  @override
  List<Object?> get props => [productId];
}

/// Charger les transactions dans une plage de dates
class LoadTransactionsByDateRange extends InventoryEvent {
  final DateTime startDate;
  final DateTime endDate;
  
  const LoadTransactionsByDateRange({
    required this.startDate,
    required this.endDate,
  });
  
  @override
  List<Object?> get props => [startDate, endDate];
}
