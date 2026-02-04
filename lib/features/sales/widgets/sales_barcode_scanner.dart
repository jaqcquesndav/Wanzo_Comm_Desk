import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../constants/constants.dart';
import '../../../core/widgets/barcode_scanner_widget.dart';
import '../../inventory/bloc/inventory_bloc.dart';
import '../../inventory/bloc/inventory_event.dart';
import '../../inventory/bloc/inventory_state.dart';
import '../../inventory/models/product.dart';

/// Widget pour scanner rapidement des produits pendant une vente
class SalesBarcodeScanner extends StatefulWidget {
  final Function(Product) onProductSelected;
  final Function(String) onBarcodeNotFound;

  const SalesBarcodeScanner({
    super.key,
    required this.onProductSelected,
    required this.onBarcodeNotFound,
  });

  @override
  State<SalesBarcodeScanner> createState() => _SalesBarcodeScannerState();
}

class _SalesBarcodeScannerState extends State<SalesBarcodeScanner> {
  bool _isSearching = false;
  String? _lastSearchedBarcode;

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryBloc, InventoryState>(
      listener: (context, state) {
        if (state is ProductsLoaded &&
            _isSearching &&
            _lastSearchedBarcode != null) {
          _handleInventorySearch(state.products, _lastSearchedBarcode!);
        }
      },
      child: BarcodeScannerWidget(
        title: 'Scanner produit pour vente',
        subtitle: 'Pointez vers le code-barres ou QR code du produit',
        onBarcodeScanned: _onBarcodeScanned,
        allowManualInput: true,
      ),
    );
  }

  void _onBarcodeScanned(String barcode) {
    setState(() {
      _isSearching = true;
      _lastSearchedBarcode = barcode;
    });

    // Rechercher le produit dans l'inventaire
    final inventoryState = context.read<InventoryBloc>().state;
    if (inventoryState is ProductsLoaded) {
      _handleInventorySearch(inventoryState.products, barcode);
    } else {
      // Recharger l'inventaire si nécessaire
      context.read<InventoryBloc>().add(const LoadProducts());
    }
  }

  void _handleInventorySearch(List<Product> products, String barcode) {
    final product = products.where((p) => p.barcode == barcode).firstOrNull;

    setState(() {
      _isSearching = false;
      _lastSearchedBarcode = null;
    });

    if (product != null) {
      // Vérifier le stock disponible
      if (product.stockQuantity <= 0) {
        _showProductOutOfStock(product);
      } else {
        // Produit trouvé avec stock disponible
        widget.onProductSelected(product);
        Navigator.of(context).pop();
      }
    } else {
      // Produit non trouvé
      widget.onBarcodeNotFound(barcode);
      _showProductNotFound(barcode);
    }
  }

  void _showProductOutOfStock(Product product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: Icon(Icons.warning_amber, color: Colors.orange, size: 48),
            title: Text('Produit en rupture de stock'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Le produit "${product.name}" n\'est plus en stock.'),
                const SizedBox(height: WanzoSpacing.sm),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.inventory_2, color: Colors.grey),
                    title: Text(product.name),
                    subtitle: Text(
                      'Stock: ${product.stockQuantity.toStringAsFixed(0)} ${product.unit.name}',
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Continuer scan'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Fermer le dialog
                  Navigator.of(context).pop(); // Fermer le scanner
                },
                child: Text('Retour à la vente'),
              ),
            ],
          ),
    );
  }

  void _showProductNotFound(String barcode) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: Icon(Icons.search_off, color: Colors.red, size: 48),
            title: Text('Produit non trouvé'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Aucun produit trouvé avec ce code-barres.'),
                const SizedBox(height: WanzoSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(WanzoSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                  ),
                  child: Text(
                    barcode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Continuer scan'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Fermer le dialog
                  _createNewProductWithBarcode(barcode);
                },
                child: Text('Ajouter produit'),
              ),
            ],
          ),
    );
  }

  void _createNewProductWithBarcode(String barcode) {
    // Navigation vers l'écran d'ajout de produit avec le code-barres
    Navigator.of(
      context,
    ).pushNamed('/inventory/add', arguments: {'barcode': barcode});
  }
}
