import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../platform/platform_service.dart';

// Import des modals natifs (Customer et Supplier conservés car légers)
import '../../../features/customer/widgets/customer_form_modal.dart';
import '../../../features/supplier/widgets/supplier_form_modal.dart';
// Import des écrans de formulaire originaux (utilisés en modal)
import '../../../features/expenses/screens/add_expense_screen.dart';
import '../../../features/inventory/screens/add_product_screen.dart';
import '../../../features/sales/screens/add_sale_screen.dart';
import '../../../features/customer/models/customer.dart';
import '../../../features/supplier/models/supplier.dart';
import '../../../features/inventory/models/product.dart';

/// Service centralisé pour la navigation adaptative vers les formulaires
/// Sur desktop: ouvre les formulaires COMPLETS dans un Dialog plein écran
/// Sur mobile: navigue vers une page complète
class FormNavigationService {
  static final FormNavigationService _instance =
      FormNavigationService._internal();
  factory FormNavigationService() => _instance;
  FormNavigationService._internal();

  static FormNavigationService get instance => _instance;

  final PlatformService _platform = PlatformService.instance;

  /// Détermine si on doit utiliser des modals (desktop/tablet) ou la navigation (mobile)
  bool shouldUseModal(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= _platform.tabletMinWidth;
  }

  /// Ouvre un écran de formulaire COMPLET dans un Dialog (desktop)
  /// Préserve toutes les fonctionnalités : pièces jointes, multi-devises, etc.
  Future<bool?> _showFormDialog(
    BuildContext context, {
    required Widget Function(VoidCallback onSaved) builder,
    double maxWidth = 800,
  }) async {
    bool success = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: builder(() {
              success = true;
              Navigator.of(dialogContext).pop();
            }),
          ),
        );
      },
    );
    return success ? true : null;
  }

  // ===== CUSTOMER =====

  /// Ouvre le formulaire d'ajout/édition de client
  Future<bool?> openCustomerForm(
    BuildContext context, {
    Customer? customer,
    VoidCallback? onSuccess,
  }) async {
    if (shouldUseModal(context)) {
      return CustomerFormModal.show(
        context,
        customer: customer,
        onSuccess: onSuccess,
      );
    } else {
      final route = customer != null ? '/customers/edit' : '/customers/add';
      if (customer != null) {
        final result = await context.push<bool>(route, extra: customer);
        if (result == true) onSuccess?.call();
        return result;
      } else {
        final result = await context.push<bool>(route);
        if (result == true) onSuccess?.call();
        return result;
      }
    }
  }

  // ===== SUPPLIER =====

  /// Ouvre le formulaire d'ajout/édition de fournisseur
  Future<bool?> openSupplierForm(
    BuildContext context, {
    Supplier? supplier,
    VoidCallback? onSuccess,
  }) async {
    if (shouldUseModal(context)) {
      return SupplierFormModal.show(
        context,
        supplier: supplier,
        onSuccess: onSuccess,
      );
    } else {
      final route = supplier != null ? '/suppliers/edit' : '/suppliers/add';
      if (supplier != null) {
        final result = await context.push<bool>(route, extra: supplier);
        if (result == true) onSuccess?.call();
        return result;
      } else {
        final result = await context.push<bool>(route);
        if (result == true) onSuccess?.call();
        return result;
      }
    }
  }

  // ===== SALE =====

  /// Ouvre le formulaire de nouvelle vente
  /// Sur desktop: Dialog avec le formulaire complet (multi-items, scanner, etc.)
  /// Sur mobile: Navigation vers la page complète
  Future<bool?> openSaleForm(
    BuildContext context, {
    VoidCallback? onSuccess,
  }) async {
    if (shouldUseModal(context)) {
      final result = await _showFormDialog(
        context,
        maxWidth: 900,
        builder: (onSaved) => AddSaleScreen(onSaved: onSaved),
      );
      if (result == true) onSuccess?.call();
      return result;
    } else {
      final result = await context.push<bool>('/sales/add');
      if (result == true) onSuccess?.call();
      return result;
    }
  }

  // ===== EXPENSE =====

  /// Ouvre le formulaire d'ajout de dépense
  /// Formulaire COMPLET avec pièces jointes, multi-devises, liaison fournisseur
  Future<bool?> openExpenseForm(
    BuildContext context, {
    VoidCallback? onSuccess,
  }) async {
    if (shouldUseModal(context)) {
      final result = await _showFormDialog(
        context,
        builder: (onSaved) => AddExpenseScreen(onSaved: onSaved),
      );
      if (result == true) onSuccess?.call();
      return result;
    } else {
      final result = await context.push<bool>('/expenses/add');
      if (result == true) onSuccess?.call();
      return result;
    }
  }

  // ===== PRODUCT =====

  /// Ouvre le formulaire d'ajout/édition de produit
  /// Formulaire COMPLET avec image produit, scanner de code-barres, date d'expiration
  Future<bool?> openProductForm(
    BuildContext context, {
    Product? product,
    VoidCallback? onSuccess,
  }) async {
    if (shouldUseModal(context)) {
      final result = await _showFormDialog(
        context,
        builder:
            (onSaved) => AddProductScreen(product: product, onSaved: onSaved),
      );
      if (result == true) onSuccess?.call();
      return result;
    } else {
      final route = product != null ? '/inventory/edit' : '/inventory/add';
      if (product != null) {
        final result = await context.push<bool>(route, extra: product);
        if (result == true) onSuccess?.call();
        return result;
      } else {
        final result = await context.push<bool>(route);
        if (result == true) onSuccess?.call();
        return result;
      }
    }
  }
}
