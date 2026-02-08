/// Export package - Services et widgets pour l'export de données
///
/// Ce package fournit des fonctionnalités d'export vers:
/// - PDF (avec mise en page professionnelle)
/// - Excel (.xlsx)
/// - CSV (format universel)
///
/// Exemple d'utilisation:
/// ```dart
/// TableExportButton(
///   config: TableExportConfig(
///     title: 'Liste des ventes',
///     headers: ['Date', 'Client', 'Montant'],
///     rows: sales.map((s) => [s.date, s.customerName, s.total]).toList(),
///     fileName: 'ventes',
///   ),
/// )
/// ```
library;

export 'table_export_service.dart';
