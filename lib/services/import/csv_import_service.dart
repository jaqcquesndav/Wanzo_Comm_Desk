import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../features/inventory/models/product.dart';

/// Résultat de l'import CSV
class CsvImportResult {
  final List<Product> products;
  final List<String> errors;
  final int totalRows;
  final int successCount;

  CsvImportResult({
    required this.products,
    required this.errors,
    required this.totalRows,
    required this.successCount,
  });
}

/// Service d'import CSV pour les produits
class CsvImportService {
  static const _uuid = Uuid();

  /// Colonnes attendues dans le CSV (ordre et noms)
  static const List<String> expectedColumns = [
    'nom',
    'categorie',
    'unite',
    'prix_achat',
    'prix_vente',
    'quantite',
    'devise',
    'taux_change',
    'code_barre',
    'description',
    'seuil_alerte',
    'taux_tva',
    'sku',
    'tags',
  ];

  /// Colonnes obligatoires
  static const List<String> requiredColumns = [
    'nom',
    'categorie',
    'unite',
    'prix_achat',
    'prix_vente',
    'quantite',
  ];

  /// Ouvre le sélecteur de fichier et parse le CSV
  static Future<CsvImportResult?> pickAndParseCSV(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();

      return parseCSV(csvString);
    } catch (e) {
      debugPrint('Erreur import CSV: $e');
      return CsvImportResult(
        products: [],
        errors: ['Erreur de lecture du fichier: $e'],
        totalRows: 0,
        successCount: 0,
      );
    }
  }

  /// Parse un contenu CSV en liste de Product
  static CsvImportResult parseCSV(String csvContent) {
    final products = <Product>[];
    final errors = <String>[];

    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) {
      return CsvImportResult(
        products: [],
        errors: ['Le fichier CSV est vide'],
        totalRows: 0,
        successCount: 0,
      );
    }

    // Première ligne = en-têtes
    final headers =
        rows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    // Vérifier les colonnes requises
    final missingColumns = <String>[];
    for (final col in requiredColumns) {
      if (!headers.contains(col)) {
        missingColumns.add(col);
      }
    }
    if (missingColumns.isNotEmpty) {
      return CsvImportResult(
        products: [],
        errors: ['Colonnes manquantes: ${missingColumns.join(", ")}'],
        totalRows: rows.length - 1,
        successCount: 0,
      );
    }

    // Parser chaque ligne de données
    for (var i = 1; i < rows.length; i++) {
      try {
        final row = rows[i];
        final rowMap = <String, String>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          rowMap[headers[j]] = row[j].toString().trim();
        }

        final product = _parseRow(rowMap, i + 1);
        if (product != null) {
          products.add(product);
        } else {
          errors.add('Ligne $i: données invalides');
        }
      } catch (e) {
        errors.add('Ligne $i: $e');
      }
    }

    return CsvImportResult(
      products: products,
      errors: errors,
      totalRows: rows.length - 1,
      successCount: products.length,
    );
  }

  static Product? _parseRow(Map<String, String> row, int lineNumber) {
    final name = row['nom'];
    if (name == null || name.isEmpty) return null;

    final category = _parseCategory(row['categorie'] ?? 'other');
    final unit = _parseUnit(row['unite'] ?? 'piece');
    final costPrice = double.tryParse(row['prix_achat'] ?? '') ?? 0.0;
    final sellingPrice = double.tryParse(row['prix_vente'] ?? '') ?? 0.0;
    final quantity = double.tryParse(row['quantite'] ?? '') ?? 0.0;
    final currency = (row['devise'] ?? 'CDF').toUpperCase();
    final exchangeRate = double.tryParse(row['taux_change'] ?? '') ?? 1.0;

    // Calculer les prix en CDF selon la devise
    double costPriceInCdf;
    double sellingPriceInCdf;
    if (currency == 'CDF') {
      costPriceInCdf = costPrice;
      sellingPriceInCdf = sellingPrice;
    } else {
      costPriceInCdf = costPrice * exchangeRate;
      sellingPriceInCdf = sellingPrice * exchangeRate;
    }

    final now = DateTime.now();
    final tags =
        (row['tags'] ?? '').isNotEmpty
            ? row['tags']!.split(';').map((t) => t.trim()).toList()
            : null;

    return Product(
      id: _uuid.v4(),
      name: name,
      description: row['description'] ?? '',
      barcode: row['code_barre'] ?? '',
      category: category,
      costPriceInCdf: costPriceInCdf,
      sellingPriceInCdf: sellingPriceInCdf,
      stockQuantity: quantity,
      unit: unit,
      alertThreshold: double.tryParse(row['seuil_alerte'] ?? '') ?? 5,
      createdAt: now,
      updatedAt: now,
      inputCurrencyCode: currency,
      inputExchangeRate: exchangeRate,
      costPriceInInputCurrency: costPrice,
      sellingPriceInInputCurrency: sellingPrice,
      taxRate: double.tryParse(row['taux_tva'] ?? ''),
      sku: row['sku'],
      tags: tags,
      syncStatus: 'pending',
    );
  }

  static ProductCategory _parseCategory(String value) {
    final lower = value.toLowerCase().trim();
    const mapping = {
      'alimentation': ProductCategory.food,
      'food': ProductCategory.food,
      'nourriture': ProductCategory.food,
      'boisson': ProductCategory.drink,
      'boissons': ProductCategory.drink,
      'drink': ProductCategory.drink,
      'electronique': ProductCategory.electronics,
      'electronics': ProductCategory.electronics,
      'vetement': ProductCategory.clothing,
      'vetements': ProductCategory.clothing,
      'clothing': ProductCategory.clothing,
      'menage': ProductCategory.household,
      'household': ProductCategory.household,
      'hygiene': ProductCategory.hygiene,
      'bureau': ProductCategory.office,
      'office': ProductCategory.office,
      'cosmetique': ProductCategory.cosmetics,
      'cosmetiques': ProductCategory.cosmetics,
      'cosmetics': ProductCategory.cosmetics,
      'pharmacie': ProductCategory.pharmaceuticals,
      'pharmaceuticals': ProductCategory.pharmaceuticals,
      'boulangerie': ProductCategory.bakery,
      'bakery': ProductCategory.bakery,
      'laitier': ProductCategory.dairy,
      'dairy': ProductCategory.dairy,
      'viande': ProductCategory.meat,
      'meat': ProductCategory.meat,
      'legumes': ProductCategory.vegetables,
      'vegetables': ProductCategory.vegetables,
      'fruits': ProductCategory.fruits,
      'autre': ProductCategory.other,
      'other': ProductCategory.other,
    };
    return mapping[lower] ?? ProductCategory.other;
  }

  static ProductUnit _parseUnit(String value) {
    final lower = value.toLowerCase().trim();
    const mapping = {
      'piece': ProductUnit.piece,
      'pièce': ProductUnit.piece,
      'pcs': ProductUnit.piece,
      'kg': ProductUnit.kg,
      'g': ProductUnit.g,
      'l': ProductUnit.l,
      'litre': ProductUnit.l,
      'ml': ProductUnit.ml,
      'paquet': ProductUnit.package,
      'package': ProductUnit.package,
      'carton': ProductUnit.box,
      'box': ProductUnit.box,
      'autre': ProductUnit.other,
      'other': ProductUnit.other,
    };
    return mapping[lower] ?? ProductUnit.piece;
  }

  /// Génère un fichier CSV template pour l'import
  static String generateTemplate() {
    final headers = expectedColumns.join(',');
    const sampleRow =
        'Savon Palmolive,hygiene,piece,500,800,100,CDF,1,123456789,Savon de toilette,10,16,,savon;hygiene';
    return '$headers\n$sampleRow';
  }
}
