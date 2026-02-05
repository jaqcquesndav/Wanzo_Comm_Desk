import 'package:flutter/material.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/features/inventory/models/product.dart';

/// Types de graphiques disponibles
enum ChartType {
  line, // Courbe
  bar, // Barres
  pie, // Secteurs (pour répartition)
}

extension ChartTypeExtension on ChartType {
  String get displayName {
    switch (this) {
      case ChartType.line:
        return 'Courbe';
      case ChartType.bar:
        return 'Barres';
      case ChartType.pie:
        return 'Secteurs';
    }
  }

  IconData get icon {
    switch (this) {
      case ChartType.line:
        return Icons.show_chart;
      case ChartType.bar:
        return Icons.bar_chart;
      case ChartType.pie:
        return Icons.pie_chart;
    }
  }
}

/// Filtres pour les ventes
enum SalesFilter {
  all, // Toutes les ventes
  products, // Uniquement les produits
  services, // Uniquement les services
}

extension SalesFilterExtension on SalesFilter {
  String get displayName {
    switch (this) {
      case SalesFilter.all:
        return 'Tout';
      case SalesFilter.products:
        return 'Produits';
      case SalesFilter.services:
        return 'Services';
    }
  }

  IconData get icon {
    switch (this) {
      case SalesFilter.all:
        return Icons.all_inclusive;
      case SalesFilter.products:
        return Icons.inventory_2;
      case SalesFilter.services:
        return Icons.miscellaneous_services;
    }
  }

  /// Filtre les items de vente selon le type
  bool matchesItem(SaleItem item) {
    switch (this) {
      case SalesFilter.all:
        return true;
      case SalesFilter.products:
        return item.itemType == SaleItemType.product;
      case SalesFilter.services:
        return item.itemType == SaleItemType.service;
    }
  }
}

/// Filtres pour les catégories de produits
enum ProductCategoryFilter {
  all,
  food,
  drink,
  electronics,
  clothing,
  household,
  hygiene,
  cosmetics,
  pharmaceuticals,
  other,
}

extension ProductCategoryFilterExtension on ProductCategoryFilter {
  String get displayName {
    switch (this) {
      case ProductCategoryFilter.all:
        return 'Toutes';
      case ProductCategoryFilter.food:
        return 'Alimentation';
      case ProductCategoryFilter.drink:
        return 'Boissons';
      case ProductCategoryFilter.electronics:
        return 'Électronique';
      case ProductCategoryFilter.clothing:
        return 'Vêtements';
      case ProductCategoryFilter.household:
        return 'Ménagers';
      case ProductCategoryFilter.hygiene:
        return 'Hygiène';
      case ProductCategoryFilter.cosmetics:
        return 'Cosmétiques';
      case ProductCategoryFilter.pharmaceuticals:
        return 'Pharma';
      case ProductCategoryFilter.other:
        return 'Autres';
    }
  }

  IconData get icon {
    switch (this) {
      case ProductCategoryFilter.all:
        return Icons.apps;
      case ProductCategoryFilter.food:
        return Icons.restaurant;
      case ProductCategoryFilter.drink:
        return Icons.local_drink;
      case ProductCategoryFilter.electronics:
        return Icons.devices;
      case ProductCategoryFilter.clothing:
        return Icons.checkroom;
      case ProductCategoryFilter.household:
        return Icons.home;
      case ProductCategoryFilter.hygiene:
        return Icons.clean_hands;
      case ProductCategoryFilter.cosmetics:
        return Icons.face;
      case ProductCategoryFilter.pharmaceuticals:
        return Icons.medical_services;
      case ProductCategoryFilter.other:
        return Icons.more_horiz;
    }
  }

  /// Convertit vers ProductCategory pour comparaison
  ProductCategory? toProductCategory() {
    switch (this) {
      case ProductCategoryFilter.all:
        return null;
      case ProductCategoryFilter.food:
        return ProductCategory.food;
      case ProductCategoryFilter.drink:
        return ProductCategory.drink;
      case ProductCategoryFilter.electronics:
        return ProductCategory.electronics;
      case ProductCategoryFilter.clothing:
        return ProductCategory.clothing;
      case ProductCategoryFilter.household:
        return ProductCategory.household;
      case ProductCategoryFilter.hygiene:
        return ProductCategory.hygiene;
      case ProductCategoryFilter.cosmetics:
        return ProductCategory.cosmetics;
      case ProductCategoryFilter.pharmaceuticals:
        return ProductCategory.pharmaceuticals;
      case ProductCategoryFilter.other:
        return ProductCategory.other;
    }
  }
}

/// Filtres pour les catégories de dépenses (groupées)
enum ExpenseCategoryFilter {
  all,
  operations, // Loyer, Services publics, Maintenance
  personnel, // Salaires, Formation
  commercial, // Marketing, Publicité, Transport
  financial, // Taxes, Assurance, Prêts
  supplies, // Fournitures, Équipement, Stock
  other, // Autres
}

extension ExpenseCategoryFilterExtension on ExpenseCategoryFilter {
  String get displayName {
    switch (this) {
      case ExpenseCategoryFilter.all:
        return 'Toutes';
      case ExpenseCategoryFilter.operations:
        return 'Opérations';
      case ExpenseCategoryFilter.personnel:
        return 'Personnel';
      case ExpenseCategoryFilter.commercial:
        return 'Commercial';
      case ExpenseCategoryFilter.financial:
        return 'Financier';
      case ExpenseCategoryFilter.supplies:
        return 'Fournitures';
      case ExpenseCategoryFilter.other:
        return 'Autres';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategoryFilter.all:
        return Icons.apps;
      case ExpenseCategoryFilter.operations:
        return Icons.settings;
      case ExpenseCategoryFilter.personnel:
        return Icons.people;
      case ExpenseCategoryFilter.commercial:
        return Icons.campaign;
      case ExpenseCategoryFilter.financial:
        return Icons.account_balance;
      case ExpenseCategoryFilter.supplies:
        return Icons.inventory;
      case ExpenseCategoryFilter.other:
        return Icons.more_horiz;
    }
  }

  /// Vérifie si une catégorie de dépense correspond à ce filtre
  bool matchesCategory(ExpenseCategory category) {
    switch (this) {
      case ExpenseCategoryFilter.all:
        return true;
      case ExpenseCategoryFilter.operations:
        return [
          ExpenseCategory.rent,
          ExpenseCategory.utilities,
          ExpenseCategory.maintenance,
          ExpenseCategory.office,
        ].contains(category);
      case ExpenseCategoryFilter.personnel:
        return [
          ExpenseCategory.salaries,
          ExpenseCategory.training,
        ].contains(category);
      case ExpenseCategoryFilter.commercial:
        return [
          ExpenseCategory.marketing,
          ExpenseCategory.advertising,
          ExpenseCategory.transport,
          ExpenseCategory.travel,
          ExpenseCategory.fuel,
        ].contains(category);
      case ExpenseCategoryFilter.financial:
        return [
          ExpenseCategory.taxes,
          ExpenseCategory.insurance,
          ExpenseCategory.loan,
          ExpenseCategory.legal,
        ].contains(category);
      case ExpenseCategoryFilter.supplies:
        return [
          ExpenseCategory.supplies,
          ExpenseCategory.equipment,
          ExpenseCategory.inventory,
          ExpenseCategory.software,
        ].contains(category);
      case ExpenseCategoryFilter.other:
        return [
          ExpenseCategory.other,
          ExpenseCategory.entertainment,
          ExpenseCategory.communication,
          ExpenseCategory.consulting,
          ExpenseCategory.research,
          ExpenseCategory.manufacturing,
        ].contains(category);
    }
  }

  /// Retourne les catégories incluses dans ce filtre
  List<ExpenseCategory> get includedCategories {
    switch (this) {
      case ExpenseCategoryFilter.all:
        return ExpenseCategory.values;
      case ExpenseCategoryFilter.operations:
        return [
          ExpenseCategory.rent,
          ExpenseCategory.utilities,
          ExpenseCategory.maintenance,
          ExpenseCategory.office,
        ];
      case ExpenseCategoryFilter.personnel:
        return [ExpenseCategory.salaries, ExpenseCategory.training];
      case ExpenseCategoryFilter.commercial:
        return [
          ExpenseCategory.marketing,
          ExpenseCategory.advertising,
          ExpenseCategory.transport,
          ExpenseCategory.travel,
          ExpenseCategory.fuel,
        ];
      case ExpenseCategoryFilter.financial:
        return [
          ExpenseCategory.taxes,
          ExpenseCategory.insurance,
          ExpenseCategory.loan,
          ExpenseCategory.legal,
        ];
      case ExpenseCategoryFilter.supplies:
        return [
          ExpenseCategory.supplies,
          ExpenseCategory.equipment,
          ExpenseCategory.inventory,
          ExpenseCategory.software,
        ];
      case ExpenseCategoryFilter.other:
        return [
          ExpenseCategory.other,
          ExpenseCategory.entertainment,
          ExpenseCategory.communication,
          ExpenseCategory.consulting,
          ExpenseCategory.research,
          ExpenseCategory.manufacturing,
        ];
    }
  }
}
