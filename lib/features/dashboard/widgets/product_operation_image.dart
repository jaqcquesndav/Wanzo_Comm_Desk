import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_state.dart';
import 'package:wanzo/features/inventory/models/product.dart';

/// Widget qui affiche l'image appropriée pour une opération :
/// - Image du produit si disponible
/// - Groupe d'images pour plusieurs produits
/// - Icône générique pour services ou sans image
class ProductOperationImage extends StatelessWidget {
  final OperationJournalEntry operation;
  final double size;

  const ProductOperationImage({
    super.key,
    required this.operation,
    this.size = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    // Si c'est un service ou pas de productId, afficher une icône générique
    if (operation.type == OperationType.saleCredit ||
        operation.type == OperationType.saleCash ||
        operation.type == OperationType.saleInstallment) {
      // Pour les ventes, vérifier s'il y a un productId
      if (operation.productId == null ||
          operation.productId!.startsWith('service-')) {
        return _buildGenericIcon(
          context,
          Icons.miscellaneous_services,
          Colors.blue,
        );
      }

      // Charger l'image du produit depuis l'inventaire
      return BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          if (state is ProductsLoaded) {
            final product = state.products.firstWhere(
              (p) => p.id == operation.productId,
              orElse: () {
                return Product(
                  id: '',
                  name: operation.productName ?? 'Produit inconnu',
                  stockQuantity: 0,
                  sellingPriceInCdf: 0,
                  costPriceInCdf: 0,
                  category: ProductCategory.other,
                  unit: ProductUnit.piece,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  inputCurrencyCode: 'CDF',
                  inputExchangeRate: 1.0,
                  costPriceInInputCurrency: 0,
                  sellingPriceInInputCurrency: 0,
                );
              },
            );

            if (product.imagePath != null && product.imagePath!.isNotEmpty) {
              return _buildProductImage(product.imagePath!);
            }
          }

          // Image par défaut pour produit sans image
          return _buildGenericIcon(context, Icons.inventory_2, Colors.green);
        },
      );
    }

    // Pour les sorties/entrées de stock
    if (operation.type == OperationType.stockOut ||
        operation.type == OperationType.stockIn) {
      if (operation.productId != null) {
        return BlocBuilder<InventoryBloc, InventoryState>(
          builder: (context, state) {
            if (state is ProductsLoaded) {
              final product = state.products.firstWhere(
                (p) => p.id == operation.productId,
                orElse: () {
                  return Product(
                    id: '',
                    name: operation.productName ?? 'Produit inconnu',
                    stockQuantity: 0,
                    sellingPriceInCdf: 0,
                    costPriceInCdf: 0,
                    category: ProductCategory.other,
                    unit: ProductUnit.piece,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    inputCurrencyCode: 'CDF',
                    inputExchangeRate: 1.0,
                    costPriceInInputCurrency: 0,
                    sellingPriceInInputCurrency: 0,
                  );
                },
              );

              if (product.imagePath != null && product.imagePath!.isNotEmpty) {
                return _buildProductImage(product.imagePath!);
              }
            }

            return _buildGenericIcon(
              context,
              operation.type == OperationType.stockOut
                  ? Icons.outbox_outlined
                  : Icons.inventory_2_outlined,
              operation.type == OperationType.stockOut
                  ? Colors.orange
                  : Colors.teal,
            );
          },
        );
      }
    }

    // Pour tous les autres types d'opérations, utiliser l'icône du type
    return _buildGenericIcon(
      context,
      operation.type.icon,
      _getColorForOperationType(operation.type),
    );
  }

  Widget _buildProductImage(String imagePath) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildGenericIcon(
              context,
              Icons.image_not_supported,
              Colors.grey,
            );
          },
        ),
      ),
    );
  }

  Widget _buildGenericIcon(BuildContext context, IconData icon, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }

  Color _getColorForOperationType(OperationType type) {
    switch (type) {
      case OperationType.saleCash:
      case OperationType.saleCredit:
      case OperationType.saleInstallment:
        return Colors.green;
      case OperationType.stockIn:
        return Colors.teal;
      case OperationType.stockOut:
        return Colors.orange;
      case OperationType.cashIn:
      case OperationType.customerPayment:
        return Colors.blue;
      case OperationType.cashOut:
      case OperationType.supplierPayment:
        return Colors.red;
      case OperationType.financingRequest:
        return Colors.purple;
      case OperationType.financingApproved:
        return Colors.indigo;
      case OperationType.financingRepayment:
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}

/// Widget pour afficher un groupe d'images de produits (pour ventes multiples)
class MultiProductOperationImages extends StatelessWidget {
  final List<String> productIds;
  final double size;
  final int maxVisible;

  const MultiProductOperationImages({
    super.key,
    required this.productIds,
    this.size = 48.0,
    this.maxVisible = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (productIds.isEmpty) {
      return SizedBox(width: size, height: size);
    }

    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        if (state is! ProductsLoaded) {
          return _buildPlaceholder();
        }

        final products =
            productIds
                .map(
                  (id) => state.products.firstWhere(
                    (p) => p.id == id,
                    orElse:
                        () => Product(
                          id: '',
                          name: 'Produit',
                          stockQuantity: 0,
                          sellingPriceInCdf: 0,
                          costPriceInCdf: 0,
                          category: ProductCategory.other,
                          unit: ProductUnit.piece,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          inputCurrencyCode: 'CDF',
                          inputExchangeRate: 1.0,
                          costPriceInInputCurrency: 0,
                          sellingPriceInInputCurrency: 0,
                        ),
                  ),
                )
                .toList();

        return SizedBox(
          width: size * 1.5,
          height: size,
          child: Stack(
            children: [
              ...products.take(maxVisible).toList().asMap().entries.map((
                entry,
              ) {
                final index = entry.key;
                final product = entry.value;
                final offset = index * (size * 0.3);

                return Positioned(
                  left: offset,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child:
                          product.imagePath != null &&
                                  product.imagePath!.isNotEmpty
                              ? Image.file(
                                File(product.imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        _buildFallbackIcon(),
                              )
                              : _buildFallbackIcon(),
                    ),
                  ),
                );
              }),
              if (productIds.length > maxVisible)
                Positioned(
                  left: maxVisible * (size * 0.3),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '+${productIds.length - maxVisible}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: size * 0.25,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory_2, color: Colors.grey),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.inventory_2, color: Colors.grey[400], size: size * 0.5),
    );
  }
}
