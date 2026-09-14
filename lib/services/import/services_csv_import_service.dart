import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../features/services/models/service_item.dart';

/// Résultat de l'import CSV de services (même forme que l'import produits).
class ServicesCsvImportResult {
  final List<ServiceItem> services;
  final List<String> errors;
  final int totalRows;
  int get successCount => services.length;

  const ServicesCsvImportResult({
    required this.services,
    required this.errors,
    required this.totalRows,
  });
}

/// Import CSV du catalogue de SERVICES, pendant de [CsvImportService] pour les
/// produits. Colonnes : `nom` (obligatoire), `categorie`, `description`,
/// `duree_minutes`, `paliers` ou `prix`, `devise`, `public`, `actif`.
///
/// `paliers` = liste « Libellé:prix » séparés par « ; », ex.
/// `Basic:45000;Premium:80000;Spéciaux:120000`. Un `*` devant un libellé le
/// marque comme palier par défaut (sinon le premier). `prix` seul crée un
/// palier « Standard ». Les prix sont convertis en CDF avec [rateToCdf].
class ServicesCsvImportService {
  static const _uuid = Uuid();

  static const List<String> expectedColumns = [
    'nom',
    'categorie',
    'description',
    'duree_minutes',
    'paliers',
    'prix',
    'devise',
    'public',
    'actif',
  ];

  static Future<ServicesCsvImportResult?> pickAndParseCSV({
    required double Function(String currencyCode) rateToCdf,
    String? metier,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final csvString = await File(result.files.single.path!).readAsString();
      return parseCSV(csvString, rateToCdf: rateToCdf, metier: metier);
    } catch (e) {
      debugPrint('Erreur import CSV services: $e');
      return ServicesCsvImportResult(
        services: const [],
        errors: ['Erreur de lecture du fichier: $e'],
        totalRows: 0,
      );
    }
  }

  static ServicesCsvImportResult parseCSV(
    String csvContent, {
    required double Function(String currencyCode) rateToCdf,
    String? metier,
  }) {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) {
      return const ServicesCsvImportResult(services: [], errors: ['Le fichier CSV est vide'], totalRows: 0);
    }
    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    if (!headers.contains('nom')) {
      return ServicesCsvImportResult(
        services: const [],
        errors: const ['Colonne manquante: nom'],
        totalRows: rows.length - 1,
      );
    }
    if (!headers.contains('paliers') && !headers.contains('prix')) {
      return ServicesCsvImportResult(
        services: const [],
        errors: const ['Colonne manquante: paliers (ou prix)'],
        totalRows: rows.length - 1,
      );
    }

    final services = <ServiceItem>[];
    final errors = <String>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, String>{};
      for (var j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j].toString().trim();
      }
      if (map.values.every((v) => v.isEmpty)) continue; // ligne vide
      try {
        final item = _parseRow(map, i + 1, rateToCdf: rateToCdf, metier: metier, position: i);
        if (item != null) {
          services.add(item);
        } else {
          errors.add('Ligne ${i + 1}: nom ou prix manquant');
        }
      } catch (e) {
        errors.add('Ligne ${i + 1}: $e');
      }
    }
    return ServicesCsvImportResult(services: services, errors: errors, totalRows: rows.length - 1);
  }

  static double? _num(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static bool _flag(String? raw, {required bool fallback}) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return fallback;
    return v == 'oui' || v == 'yes' || v == 'true' || v == '1' || v == 'x';
  }

  static ServiceItem? _parseRow(
    Map<String, String> row,
    int line, {
    required double Function(String currencyCode) rateToCdf,
    String? metier,
    required int position,
  }) {
    final name = row['nom'] ?? '';
    if (name.isEmpty) return null;
    final currency = (row['devise'] ?? 'CDF').toUpperCase().isEmpty ? 'CDF' : (row['devise'] ?? 'CDF').toUpperCase();
    final rate = rateToCdf(currency);

    final tiers = <ServicePriceTier>[];
    final rawTiers = row['paliers'] ?? '';
    if (rawTiers.isNotEmpty) {
      var hasDefault = false;
      for (final part in rawTiers.split(';')) {
        final p = part.trim();
        if (p.isEmpty) continue;
        final sep = p.lastIndexOf(':');
        if (sep <= 0) throw 'palier invalide « $p » (attendu Libellé:prix)';
        var label = p.substring(0, sep).trim();
        final price = _num(p.substring(sep + 1));
        if (price == null) throw 'prix invalide pour « $label »';
        final isDefault = label.startsWith('*');
        if (isDefault) label = label.substring(1).trim();
        hasDefault = hasDefault || isDefault;
        tiers.add(ServicePriceTier(
          code: ServicePriceTier.codeFromLabel(label),
          label: label,
          priceCdf: price * rate,
          isDefault: isDefault,
        ));
      }
      if (tiers.isNotEmpty && !hasDefault) tiers[0] = tiers[0].copyWith(isDefault: true);
    } else {
      final price = _num(row['prix']);
      if (price == null) return null;
      tiers.add(ServicePriceTier(code: 'standard', label: 'Standard', priceCdf: price * rate, isDefault: true));
    }
    if (tiers.isEmpty) return null;

    final duration = _num(row['duree_minutes']);
    return ServiceItem(
      id: _uuid.v4(),
      name: name,
      description: (row['description'] ?? '').isEmpty ? null : row['description'],
      category: (row['categorie'] ?? '').isEmpty ? null : row['categorie'],
      durationMinutes: duration?.round(),
      priceTiers: tiers,
      activityModes: const [],
      metier: metier,
      isPublic: _flag(row['public'], fallback: false),
      active: _flag(row['actif'], fallback: true),
      position: position,
      pendingSync: true,
    );
  }

  /// Modèle de fichier à remplir (en-têtes + deux exemples).
  static String generateTemplate() {
    final headers = expectedColumns.join(',');
    const rows = [
      'Vidange moteur,Entretien,Huile et filtre,45,Basic:45000;*Premium:80000;Spéciaux:120000,,CDF,oui,oui',
      'Chemise,Nettoyage à sec,,,Standard:3000;Express:5000,,CDF,oui,oui',
      'Livraison,Prestation,Livraison en ville,,,5000,CDF,non,oui',
    ];
    return '$headers\n${rows.join('\n')}';
  }
}
