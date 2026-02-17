import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../platform/platform_service.dart';

// Import des modals de formulaire
import '../../../features/customer/widgets/customer_form_modal.dart';
import '../../../features/supplier/widgets/supplier_form_modal.dart';
import '../../../features/expenses/widgets/expense_form_modal.dart';
import '../../../features/financing/widgets/financing_form_modal.dart';
import '../../../features/inventory/widgets/product_form_modal.dart';
import '../../../features/customer/models/customer.dart';
import '../../../features/supplier/models/supplier.dart';
import '../../../features/inventory/models/product.dart';

/// Service centralisé pour la navigation adaptative vers les formulaires
/// Sur desktop: ouvre une modal
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

  // ===== CUSTOMER =====

  /// Ouvre le formulaire d'ajout/édition de client
  /// Retourne true si le client a été créé/modifié avec succès
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
      // Navigation mobile traditionnelle
      final route = customer != null ? '/customers/edit' : '/customers/add';

      // Pour l'édition, on passe le customer via extra
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
  /// Retourne true si le fournisseur a été créé/modifié avec succès
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
  /// Toujours en navigation car formulaire très complexe (multi-items)
  Future<void> openSaleForm(BuildContext context) async {
    await context.push('/sales/add');
  }

  // ===== EXPENSE =====

  /// Ouvre le formulaire d'ajout de dépense
  /// Retourne true si la dépense a été créée avec succès
  Future<bool?> openExpenseForm(
    BuildContext context, {
    VoidCallback? onSuccess,
  }) async {
    if (shouldUseModal(context)) {
      return ExpenseFormModal.show(context, onSuccess: onSuccess);
    } else {
      final result = await context.push<bool>('/expenses/add');
      if (result == true) onSuccess?.call();
      return result;
    }
  }

  // ===== PRODUCT =====

  /// Ouvre le formulaire d'ajout/édition de produit
  /// Retourne true si le produit a été créé/modifié avec succès
  Future<bool?> openProductForm(
    BuildContext context, {
    Product? product,
    VoidCallback? onSuccess,
  }) async {
    if (shouldUseModal(context)) {
      return ProductFormModal.show(
        context,
        product: product,
        onSuccess: onSuccess,
      );
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

  // ===== FINANCING =====

  /// Ouvre le formulaire de nouvelle demande de financement
  /// Retourne true si la demande a été créée avec succès
  Future<bool?> openFinancingForm(
    BuildContext context, {
    VoidCallback? onSuccess,
  }) async {
    if (shouldUseModal(context)) {
      return FinancingFormModal.show(context, onSuccess: onSuccess);
    } else {
      final result = await context.push<bool>('/financing/add');
      if (result == true) onSuccess?.call();
      return result;
    }
  }
}
